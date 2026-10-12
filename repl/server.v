module repl

import net
import os
import rand
import sync
import time
import x.json2
import model
import parser
import playback
import smf

pub const version = '0.1.0'

const nrepl_port_file = '.alda-nrepl-port'

// A Server is an Alda REPL server, speaking the nREPL protocol (bencode over
// TCP), so that editor integrations built for Alda work with valda too.
//
// Unlike Alda, there's no separate player process: the server plays audio
// itself, through the built-in synthesizer.
@[heap]
pub struct Server {
pub mut:
	port int
mut:
	// The total input (Alda code) evaluated so far.
	input  string
	score  &model.Score = model.new_score()
	player playback.Player
	// Whether audio output is available.
	audio bool
	// Requests are processed one at a time, since all clients share the score.
	mu       &sync.Mutex      = sync.new_mutex()
	listener &net.TcpListener = unsafe { nil }
	running  bool
}

pub fn new_server(audio bool) &Server {
	return &Server{
		audio: audio
	}
}

fn str_list(items []string) BValue {
	return BValue(items.map(BValue(it)))
}

fn (mut s Server) reset_state() {
	if s.audio {
		s.player.stop()
	}
	s.input = ''
	s.score = model.new_score()
}

// update_score_with_input parses `input`, updates the score, and returns the
// options needed to transmit just the new events, lined up after the events
// that were previously transmitted for each part.
fn (mut s Server) update_score_with_input(input string) !playback.Options {
	event_count_before := s.score.events.len

	updates := parser.parse_updates('', input)!
	s.score.update(...updates)!

	s.input += input.trim_space() + '\n'

	// The sync offset for each part is where the last previously transmitted
	// note ends. Keyed by part ID, which is stable across voice groups.
	mut sync_offsets := map[string]f64{}
	for event in s.score.events[..event_count_before] {
		end := event.offset + event.duration
		id := event.part.id
		if current := sync_offsets[id] {
			if end > current {
				sync_offsets[id] = end
			}
		} else {
			sync_offsets[id] = end
		}
	}

	// Clamp each sync offset to the earliest new event for that part, so that
	// no event is scheduled at a negative relative offset.
	for event in s.score.events[event_count_before..] {
		id := event.part.id
		if current := sync_offsets[id] {
			if event.offset < current {
				sync_offsets[id] = event.offset
			}
		}
	}

	return playback.Options{
		from_index:   event_count_before
		sync_offsets: sync_offsets
	}
}

fn (mut s Server) require_audio() ! {
	if !s.audio {
		return error('audio output is not available (see `valda doctor`)')
	}
}

fn (mut s Server) eval_and_play(input string, from string, to string) ! {
	s.require_audio()!
	opts := s.update_score_with_input(input)!
	msgs := playback.score_messages(s.score, playback.Options{
		...opts
		from: from
		to:   to
	})!
	s.player.schedule(msgs)
}

fn (mut s Server) load(input string) ! {
	s.reset_state()
	s.update_score_with_input(input)!
}

fn (mut s Server) replay(from string, to string) ! {
	input := s.input
	s.reset_state()
	s.eval_and_play(input, from, to)!
}

fn (s &Server) export_midi() ![]u8 {
	mut score := model.new_score()
	score.update(...parser.parse_updates('', s.input)!)!
	return smf.encode(playback.score_messages(score)!)
}

fn describe_response() map[string]BValue {
	mut ops := map[string]BValue{}
	for op in ['clone', 'describe', 'eval', 'eval-and-play', 'export', 'instruments', 'load',
		'new-score', 'replay', 'score-ast', 'score-data', 'score-events', 'score-text', 'stop'] {
		ops[op] = map[string]BValue{}
	}
	return {
		'ops':      BValue(ops)
		'versions': BValue({
			'alda':  BValue({
				'version-string': BValue(version)
			})
			'valda': BValue({
				'version-string': BValue(version)
			})
		})
	}
}

fn get_string(msg map[string]BValue, key string) ?string {
	value := msg[key] or { return none }
	if value is string {
		return value
	}
	return none
}

fn required_string(msg map[string]BValue, key string) !string {
	value := msg[key] or { return error('Request field missing: ${key}') }
	if value is string {
		return value
	}
	return error('Expected "${key}" to be of type `string`.')
}

// handle processes a request and returns the response.
pub fn (mut s Server) handle(msg map[string]BValue) map[string]BValue {
	s.mu.@lock()
	defer {
		s.mu.unlock()
	}

	mut response := map[string]BValue{}
	mut status := ['done']

	result := s.dispatch(msg, mut response) or {
		status << 'error'
		if err.msg() == 'unknown-op' {
			status << 'unknown-op'
		} else {
			response['problems'] = str_list([err.msg()])
		}
		false
	}
	_ = result

	response['status'] = str_list(status)
	if session := msg['session'] {
		response['session'] = session
	}
	if id := msg['id'] {
		response['id'] = id
	}
	return response
}

fn (mut s Server) dispatch(msg map[string]BValue, mut response map[string]BValue) !bool {
	op := required_string(msg, 'op')!

	match op {
		// Sessions don't mean much to an Alda REPL server; this is for nREPL
		// protocol adherence.
		'clone' {
			response['new-session'] = rand.uuid_v4()
		}
		'describe' {
			for k, v in describe_response() {
				response[k] = v
			}
		}
		'eval' {
			response['value'] = '¯\\_(ツ)_/¯'
		}
		'eval-and-play' {
			s.eval_and_play(required_string(msg, 'code')!, '', '')!
		}
		'export' {
			response['binary-data'] = s.export_midi()!.bytestr()
		}
		'instruments' {
			response['instruments'] = str_list(model.instruments_list())
		}
		'load' {
			s.load(required_string(msg, 'code')!)!
		}
		'new-score' {
			s.reset_state()
		}
		'replay' {
			s.replay(get_string(msg, 'from') or { '' }, get_string(msg, 'to') or { '' })!
		}
		'score-data' {
			response['data'] = model.encode_json(s.score.json())
		}
		'score-events' {
			updates := parser.parse_updates('', s.input)!
			response['events'] = model.encode_json(json2.Any(updates.map(it.json())))
		}
		'score-ast' {
			response['ast'] = model.encode_json(parser.parse_string(s.input)!.json())
		}
		'score-text' {
			response['text'] = s.input
		}
		'stop' {
			s.require_audio()!
			s.player.stop()
		}
		else {
			return error('unknown-op')
		}
	}
	return true
}

@[params]
pub struct ListenOptions {
pub:
	// The address to listen on. The default only accepts connections from this
	// machine; 0.0.0.0 accepts them from anywhere, e.g. from outside a
	// container.
	host string = '127.0.0.1'
}

// listen starts accepting connections in the background. Port 0 picks an
// available port. Returns the port.
pub fn (mut s Server) listen(port int, opts ListenOptions) !int {
	mut listener := net.listen_tcp(.ip, '${opts.host}:${port}')!
	listener.set_accept_timeout(net.infinite_timeout)
	addr := listener.addr()!
	s.port = addr.port()!
	s.listener = listener
	s.running = true

	os.write_file(nrepl_port_file, s.port.str()) or {}

	spawn s.accept_loop()
	return s.port
}

fn (mut s Server) accept_loop() {
	for s.running {
		mut conn := s.listener.accept() or {
			if !s.running {
				break
			}
			time.sleep(10 * time.millisecond)
			continue
		}
		spawn s.serve_connection(mut conn)
	}
}

fn (mut s Server) serve_connection(mut conn net.TcpConn) {
	conn.set_read_timeout(net.infinite_timeout)
	mut reader := new_breader(conn)
	defer {
		conn.close() or {}
	}
	for {
		decoded := reader.decode() or { break }
		if decoded is map[string]BValue {
			response := s.handle(decoded)
			conn.write_string(bencode(response)) or { break }
		}
	}
}

// close cleans up after the server, e.g. removing the nREPL port file.
pub fn (mut s Server) close() {
	if !s.running {
		return
	}
	s.running = false
	if os.exists(nrepl_port_file) {
		content := os.read_file(nrepl_port_file) or { '' }
		if content.trim_space() == s.port.str() {
			os.rm(nrepl_port_file) or {}
		}
	}
	if !isnil(s.listener) {
		s.listener.close() or {}
	}
}
