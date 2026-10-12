module repl

import net
import os
import rand
import readline
import strings
import time
import x.json2
import model
import parser

const logo = '
 ██╗   ██╗ █████╗ ██╗     ██████╗  █████╗
 ██║   ██║██╔══██╗██║     ██╔══██╗██╔══██╗
 ██║   ██║███████║██║     ██║  ██║███████║
 ╚██╗ ██╔╝██╔══██║██║     ██║  ██║██╔══██║
  ╚████╔╝ ██║  ██║███████╗██████╔╝██║  ██║
   ╚═══╝  ╚═╝  ╚═╝╚══════╝╚═════╝ ╚═╝  ╚═╝
'

// A Client is a stateful Alda REPL client, talking to a server over nREPL.
pub struct Client {
mut:
	running bool         = true
	conn    &net.TcpConn = unsafe { nil }
	reader  BReader
	session string
	// The file used by :load and :save.
	input_filepath string
}

// connect connects to a REPL server, retrying for a few seconds.
pub fn connect(host string, port int) !&Client {
	deadline := time.now().add(5 * time.second)
	for {
		mut conn := net.dial_tcp('${host}:${port}') or {
			if time.now() > deadline {
				return error('Attempting to connect to ${host}:${port} resulted in this error:

  ${err.msg()}

Is there an Alda REPL server running on that port? If not, you can start one
by running:

  valda repl --server --port ${port}')
			}
			time.sleep(100 * time.millisecond)
			continue
		}
		conn.set_read_timeout(30 * time.second)
		return &Client{
			conn:   conn
			reader: new_breader(conn)
		}
	}
	return error('unreachable')
}

pub fn (mut c Client) disconnect() {
	if !isnil(c.conn) {
		c.conn.close() or {}
	}
}

// send sends a request and returns the response.
pub fn (mut c Client) send(request map[string]BValue) !map[string]BValue {
	mut req := request.clone()
	if c.session != '' {
		req['session'] = c.session
	}
	id := rand.uuid_v4()
	req['id'] = id

	c.conn.write_string(bencode(req))!
	response := c.reader.decode()!
	if response !is map[string]BValue {
		return error('response could not be decoded into the expected type')
	}
	res := response as map[string]BValue

	res_id := get_string(res, 'id') or { '' }
	if res_id != id {
		return error('unexpected "id" in response. Expected ${id}, got ${res_id}')
	}
	return res
}

// response_errors returns the problems reported in a response, if any.
pub fn response_errors(res map[string]BValue) []string {
	statuses := res['status'] or { return ['malformed response'] }
	if statuses !is []BValue {
		return ['malformed response']
	}
	if !(statuses as []BValue).any(it is string && it == 'error') {
		return []
	}
	problems := res['problems'] or { return ['request failed: ${bvalue_to_json(statuses)}'] }
	if problems is []BValue {
		return problems.map(if it is string { it } else { bvalue_to_json(it).str() })
	}
	return ['request failed']
}

// request sends a request and fails if the server reports errors.
fn (mut c Client) request(req map[string]BValue) !map[string]BValue {
	res := c.send(req)!
	errors := response_errors(res)
	if errors.len > 0 {
		return error(errors.join('\n'))
	}
	return res
}

fn op(name string) map[string]BValue {
	return {
		'op': BValue(name)
	}
}

// start_session makes the initial nREPL "clone" and "describe" requests.
pub fn (mut c Client) start_session() !string {
	res := c.request(op('clone'))!
	if session := get_string(res, 'new-session') {
		c.session = session
	}

	described := c.request(op('describe'))!
	ops := described['ops'] or { return error('the server does not appear to be an Alda server') }
	if ops !is map[string]BValue || 'eval-and-play' !in (ops as map[string]BValue) {
		return error('the server does not appear to support the `eval-and-play` op')
	}

	versions := described['versions'] or { BValue('') }
	if versions is map[string]BValue {
		if alda := versions['alda'] {
			if alda is map[string]BValue {
				if v := get_string(alda, 'version-string') {
					return v
				}
			}
		}
	}
	return 'unknown'
}

fn (mut c Client) score_string(op_name string, key string) !string {
	res := c.request(op(op_name))!
	return get_string(res, key) or {
		return error('the response from the REPL server did not contain the score ${key}')
	}
}

fn (mut c Client) score_data() !json2.Any {
	return json2.decode[json2.Any](c.score_string('score-data', 'data')!)!
}

// split_args splits a command's arguments shell-style (with quotes).
fn split_args(s string) []string {
	mut args := []string{}
	mut current := strings.new_builder(16)
	mut quote := u8(0)
	mut has := false
	for ch in s {
		if quote != 0 {
			if ch == quote {
				quote = 0
			} else {
				current.write_u8(ch)
			}
		} else if ch == `"` || ch == `'` {
			quote = ch
			has = true
		} else if ch == ` ` || ch == `\t` {
			if has {
				args << current.str()
				has = false
			}
		} else {
			current.write_u8(ch)
			has = true
		}
	}
	if has {
		args << current.str()
	}
	return args
}

struct ReplCommand {
	summary string
	details string
}

const commands = {
	'export':      ReplCommand{'Exports the current score as a MIDI file.', 'Example usage:

  :export my-score.mid'}
	'help':        ReplCommand{'Displays this help text.', 'Usage:

  :help help
  :help new'}
	'instruments': ReplCommand{'Displays the list of available instruments.', ''}
	'load':        ReplCommand{'Loads a score file (*.alda) into the current REPL session.', 'Usage:

  :load examples/bach_cello_suite_no_1.alda
  :load /Users/rick/Scores/love_is_alright_tonite.alda

After using :load <filename> to load a file, or after using :save to save the
working score to a file, running :load without arguments will reload the score
file into the REPL server.'}
	'new':         ReplCommand{'Resets the REPL server state and initializes a new score.', ''}
	'parts':       ReplCommand{'Displays information about the parts in the current score.', ''}
	'play':        ReplCommand{'Plays the current score.', 'Can take optional `from` and `to` arguments, in the form of markers or mm:ss
times.

Without arguments, will play the entire score from beginning to end.

Example usage:

  :play
  :play from 0:05
  :play to 0:10
  :play from 0:05 to 0:10
  :play from guitarIn
  :play to verse
  :play from verse to bridge'}
	'quit':        ReplCommand{'Exits the Alda REPL session.', ''}
	'save':        ReplCommand{'Saves the current score into a file (*.alda).', 'Usage:

  :save examples/bach_cello_suite_no_1.alda
  :save /Users/rick/Scores/love_is_alright_tonite.alda

After using :save <filename> to save a file, running :save again without
arguments will save the updated score to the same file.'}
	'score':       ReplCommand{'Prints information about the current score.', 'Example usage:

  Print the text (Alda code) of the score (both commands are equivalent):
    :score
    :score text

  Print a summary of the score, including information about instruments and
  markers:
    :score info

  Print a data representation of the score (This is the output that you get
  when you run `valda parse -o data ...` at the command line.):
    :score data

  Print the parsed events output of the score (This is the output that you get
  when you run `valda parse -o events ...` at the command line.):
    :score events

  Print the parsed AST output of the score (This is the output that you get
  when you run `valda parse -o ast-human ...` at the command line.):
    :score ast'}
	'stop':        ReplCommand{'Stops playback.', ''}
	'version':     ReplCommand{'Displays the version numbers of the Alda server and client.', ''}
}

fn commands_summary() string {
	mut names := commands.keys()
	names.sort()
	mut max_len := 0
	for name in names {
		if name.len > max_len {
			max_len = name.len
		}
	}
	mut sb := strings.new_builder(512)
	for name in names {
		cmd := commands[name] or { continue }
		indicator := if cmd.details != '' { ' (*)' } else { '' }
		sb.write_string('    :${name}${' '.repeat(max_len - name.len + 2)}${cmd.summary}${indicator}\n')
	}
	return sb.str()
}

fn invalid_args(args []string) IError {
	return error('invalid arguments: ${args}')
}

fn (mut c Client) handle_command(name string, args_string string) ! {
	args := split_args(args_string)
	match name {
		'export' {
			if args.len != 1 {
				return invalid_args(args)
			}
			res := c.request(op('export'))!
			data := get_string(res, 'binary-data') or {
				return error('the response from the REPL server did not contain the exported score')
			}
			os.write_file(args[0], data)!
		}
		'help' {
			if args.len == 0 {
				println('For commands marked with (*), more detailed information about the command is
available via the :help command.

e.g. :help play

Available commands:

${commands_summary()}')
				return
			}
			subject := args.join(' ')
			cmd := commands[subject] or {
				return error("no documentation available for '${subject}'")
			}
			println(cmd.summary + '\n')
			if cmd.details != '' {
				println(cmd.details + '\n')
			}
		}
		'instruments' {
			res := c.request(op('instruments'))!
			instruments := res['instruments'] or { BValue([]BValue{}) }
			if instruments is []BValue {
				for instrument in instruments {
					if instrument is string {
						println(instrument)
					}
				}
			}
		}
		'load' {
			match args.len {
				0 {
					if c.input_filepath == '' {
						return error('please specify the path to a file to load')
					}
				}
				1 {
					c.input_filepath = args[0]
				}
				else {
					return invalid_args(args)
				}
			}
			contents := os.read_file(c.input_filepath)!
			c.request({
				'op':   BValue('load')
				'code': BValue(contents)
			})!
		}
		'new' {
			c.request(op('new-score'))!
		}
		'parts' {
			data := c.score_data()!
			print_parts_info(data)
			println('')
		}
		'play' {
			mut req := op('replay')
			mut i := 0
			for i < args.len {
				if i == args.len - 1 || args[i] !in ['from', 'to'] || args[i] in req {
					return invalid_args(args)
				}
				req[args[i]] = args[i + 1]
				i += 2
			}
			c.request(req)!
		}
		'quit' {
			c.running = false
		}
		'save' {
			match args.len {
				0 {
					if c.input_filepath == '' {
						return error('please specify the path to a file')
					}
				}
				1 {
					c.input_filepath = args[0]
				}
				else {
					return invalid_args(args)
				}
			}
			os.write_file(c.input_filepath, c.score_string('score-text', 'text')!)!
		}
		'score' {
			subcommand := match args.len {
				0 { 'text' }
				1 { args[0] }
				else { return invalid_args(args) }
			}
			match subcommand {
				'text' {
					println(c.score_string('score-text', 'text')!)
				}
				'data' {
					println(model.encode_json_pretty(c.score_data()!))
				}
				'events' {
					events := json2.decode[json2.Any](c.score_string('score-events', 'events')!)!
					println(model.encode_json_pretty(events))
				}
				'ast' {
					ast_json := c.score_string('score-ast', 'ast')!
					println(human_readable_ast_json(json2.decode[json2.Any](ast_json)!))
				}
				'info' {
					print_score_info(c.score_data()!)
				}
				else {
					return invalid_args(args)
				}
			}
		}
		'stop' {
			c.request(op('stop'))!
		}
		'version' {
			println('Client version: ${version}')
			server_version := c.start_session()!
			println('Server version: ${server_version}')
		}
		else {
			return error('unrecognized command: ${name}')
		}
	}
}

// human_readable_ast_json renders the JSON representation of an AST (as sent
// by the server) the same way as `valda parse -o ast-human`.
fn human_readable_ast_json(node json2.Any) string {
	mut sb := strings.new_builder(1024)
	write_ast_json(node, 0, mut sb)
	return sb.str().trim_right('\n')
}

fn write_ast_json(node json2.Any, indent int, mut sb strings.Builder) {
	m := node.as_map()
	sb.write_string('  '.repeat(indent))
	sb.write_string((m['type'] or { json2.Any('') }).str())
	if sc := m['source-context'] {
		scm := sc.as_map()
		line := (scm['line'] or { json2.Any(0) }).int()
		column := (scm['column'] or { json2.Any(0) }).int()
		sb.write_string(' [${line}:${column}]')
	}
	if lit := m['literal'] {
		match lit {
			string { sb.write_string(': "${lit}"') }
			else { sb.write_string(': ${parser.fmt_number(lit.f64())}') }
		}
	}
	sb.write_string('\n')
	if children := m['children'] {
		for child in children.as_array() {
			write_ast_json(child, indent + 1, mut sb)
		}
	}
}

fn print_parts_info(data json2.Any) {
	println('Parts:')
	parts := (data.as_map()['parts'] or { json2.Any(map[string]json2.Any{}) }).as_map()
	if parts.len == 0 {
		println('  (none)')
		return
	}
	mut ids := parts.keys()
	ids.sort()
	for id in ids {
		part := (parts[id] or { continue }).as_map()
		println('  ${id} (${(part['stock-instrument'] or { json2.Any('') }).str()})')
	}
}

fn print_score_info(data json2.Any) {
	m := data.as_map()
	print_parts_info(data)
	println('')

	println('Current parts:')
	parts := (m['parts'] or { json2.Any(map[string]json2.Any{}) }).as_map()
	current := (m['current-parts'] or { json2.Any([]json2.Any{}) }).as_array()
	if current.len == 0 {
		println('  (none)')
	} else {
		for id in current {
			part := (parts[id.str()] or { json2.Any(map[string]json2.Any{}) }).as_map()
			println('  ${id.str()} (${(part['stock-instrument'] or { json2.Any('') }).str()})')
		}
	}
	println('')

	events := (m['events'] or { json2.Any([]json2.Any{}) }).as_array()
	println('Events:\n  ${events.len}\n')

	println('Markers:')
	markers := (m['markers'] or { json2.Any(map[string]json2.Any{}) }).as_map()
	if markers.len == 0 {
		println('  (none)')
	} else {
		mut names := markers.keys()
		names.sort_with_compare(fn [markers] (a &string, b &string) int {
			oa := (markers[*a] or { json2.Any(0) }).f64()
			ob := (markers[*b] or { json2.Any(0) }).f64()
			return if oa < ob {
				-1
			} else if oa > ob {
				1
			} else {
				0
			}
		})
		for name in names {
			println('  ${name} (${(markers[name] or { json2.Any(0) }).f64():.6f})')
		}
	}
	println('')
}

fn history_file() string {
	return os.join_path(os.cache_dir(), 'valda', 'repl-history')
}

fn load_history(mut r readline.Readline) {
	lines := os.read_lines(history_file()) or { return }
	// previous_lines[0] is the line being edited; history follows, newest first.
	r.previous_lines = [[]rune{}]
	for i := lines.len - 1; i >= 0 && r.previous_lines.len < 1000; i-- {
		if lines[i].len > 0 {
			r.previous_lines << lines[i].runes()
		}
	}
}

fn append_history(line string) {
	path := history_file()
	os.mkdir_all(os.dir(path)) or { return }
	mut f := os.open_append(path) or { return }
	f.writeln(line) or {}
	f.close()
}

fn complete(prefix string) []string {
	if !prefix.starts_with(':') || prefix.contains(' ') {
		return []
	}
	mut names := commands.keys().map(':' + it).filter(it.starts_with(prefix))
	names.sort()
	return names
}

// run_client runs an interactive REPL session against the server at
// host:port.
pub fn run_client(host string, port int) ! {
	mut c := connect(host, port)!
	defer {
		c.disconnect()
	}

	server_version := c.start_session()!

	println('${logo.trim('\n')}

    Client version: ${version}
    Server version: ${server_version}

Type :help for a list of available commands.
')

	mut r := readline.Readline{
		skip_empty:          true
		completion_callback: complete
	}
	load_history(mut r)

	for c.running {
		line := r.read_line('alda> ') or { break }
		input := line.trim_space()
		if input.len == 0 {
			continue
		}
		append_history(input)

		if input.starts_with(':') && input.len > 1 {
			rest := input[1..]
			name := rest.all_before(' ')
			args := if rest.contains(' ') { rest.all_after(' ') } else { '' }
			c.handle_command(name, args) or { println('ERROR: ${err.msg()}') }
			continue
		}

		match input {
			'quit', 'exit', 'bye' {
				c.running = false
			}
			else {
				c.request({
					'op':   BValue('eval-and-play')
					'code': BValue(input)
				}) or { println('ERROR: ${err.msg()}') }
			}
		}
	}
}

// send_message sends a single request (e.g. from `repl --message`) in a new
// session and returns the response.
pub fn send_message(host string, port int, message map[string]BValue) !map[string]BValue {
	mut c := connect(host, port)!
	defer {
		c.disconnect()
	}
	c.start_session()!
	return c.send(message)
}
