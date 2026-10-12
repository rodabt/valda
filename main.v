module main

import cli
import os
import time
import x.json2
import engine
import model
import musicxml
import parser
import playback
import repl
import smf

fn main() {
	mut app := cli.Command{
		name:          'valda'
		description:   'valda: a text-based language for music composition (Alda, reimplemented in V)'
		version:       repl.version
		posix_mode:    true
		sort_commands: true
		flags:         [
			cli.Flag{
				flag:        .string
				name:        'soundfont'
				abbrev:      'S'
				description: 'The SoundFont (.sf2) to use for playback'
				global:      true
			},
		]
		commands:      [
			play_command(),
			parse_command(),
			export_command(),
			import_command(),
			format_command(),
			repl_command(),
			stop_command(),
			instruments_command(),
			version_command(),
			doctor_command(),
		]
	}
	app.setup()
	app.parse(os.args)
}

// report_errors prints a command's error (without the cli module's prefix)
// and exits with a non-zero status.
fn report_errors(f fn (cli.Command) !) fn (cli.Command) ! {
	return fn [f] (cmd cli.Command) ! {
		f(cmd) or {
			eprintln(err.msg())
			exit(1)
		}
	}
}

fn string_flag(name string, abbrev string, description string) cli.Flag {
	return cli.Flag{
		flag:        .string
		name:        name
		abbrev:      abbrev
		description: description
	}
}

fn input_flags() []cli.Flag {
	return [
		string_flag('file', 'f', 'Read Alda source code from a file'),
		string_flag('code', 'c', 'Supply Alda source code as a string'),
	]
}

fn source_input_options(command string) string {
	suffix := fn [command] (s string) string {
		return if command == 'export' { s } else { '' }
	}
	return 'You can provide input in one of three ways:

The path to a file (-f, --file):
  valda ${command} -f path/to/my-score.alda${suffix(' -o my-score.mid')}

A string of code (-c, --code):
  valda ${command} -c "harpsichord: o5 d+8 < b g+ e d+1"${suffix(' -o harpsy.mid')}

Text piped into the process on stdin:
  echo "glockenspiel: o5 g8 < g > g e4 d4." | valda ${command}${suffix(' -o glock.mid')}'
}

struct Input {
	filename string
	code     string
}

// read_input reads Alda source code from -f, -c, or stdin.
fn read_input(cmd cli.Command, command string) !Input {
	file := cmd.flags.get_string('file') or { '' }
	code := cmd.flags.get_string('code') or { '' }

	if file != '' {
		if !os.exists(file) {
			return error("Failed to open ${file}. The file does not seem to exist.

Please check that you haven't misspelled the file name, etc.")
		}
		return Input{file, os.read_file(file)!}
	}
	if code != '' {
		return Input{'', code}
	}
	if os.is_atty(0) == 0 {
		stdin := os.get_raw_lines_joined()
		if stdin.trim_space() != '' {
			return Input{'', stdin}
		}
	}
	return error('No Alda source code input supplied.\n\n${source_input_options(command)}')
}

fn build_score(input Input) !&model.Score {
	updates := parser.parse_updates(input.filename, input.code)!
	mut score := model.new_score()
	score.update(...updates)!
	return score
}

fn soundfont_flag(cmd cli.Command) string {
	return cmd.flags.get_string('soundfont') or { '' }
}

fn open_audio(cmd cli.Command) ! {
	sf := find_soundfont(soundfont_flag(cmd))!
	engine.open(sf) or { return error('Failed to start audio: ${err.msg()}') }
	// With no sound device, miniaudio falls back to a backend that discards
	// everything; playing would be silent, so treat it as a failure.
	if engine.backend() == 'Null' {
		engine.close()
		return error(no_audio_device)
	}
}

const no_audio_device = "No audio device found, so playback would be silent.

To hear the score, export it instead (valda export -O wav) and play the file.
In a Docker container, see the Docker section of the README to use the
host's sound server."

// ---------------------------------------------------------------------------
// play

fn play_command() cli.Command {
	mut flags := input_flags()
	flags << string_flag('from', 'F', 'Time marking (e.g. 0:30) or marker to start from')
	flags << string_flag('to', 'T', 'Time marking (e.g. 1:00) or marker to end at')
	flags << cli.Flag{
		flag:        .int
		name:        'port'
		abbrev:      'p'
		description: 'Play in a running valda REPL server on this port, instead of in-process'
	}
	return cli.Command{
		name:            'play'
		description:     'Evaluate and play Alda source code'
		man_description: 'Evaluate and play Alda source code\n\n${source_input_options('play')}'
		posix_mode:      true
		flags:           flags
		execute:         report_errors(run_play)
	}
}

fn run_play(cmd cli.Command) ! {
	input := read_input(cmd, 'play')!
	from := cmd.flags.get_string('from') or { '' }
	to := cmd.flags.get_string('to') or { '' }
	port := cmd.flags.get_int('port') or { 0 }

	if port > 0 {
		res := repl.send_message('127.0.0.1', port, {
			'op':   repl.BValue('eval-and-play')
			'code': repl.BValue(input.code)
		})!
		errors := repl.response_errors(res)
		if errors.len > 0 {
			return error(errors.join('\n'))
		}
		return
	}

	score := build_score(input)!
	msgs := playback.score_messages(score, from: from, to: to)!

	open_audio(cmd)!
	defer {
		engine.close()
	}

	eprintln('Playing...')
	mut player := playback.Player{}
	player.schedule(msgs)
	player.wait(3000)
}

// ---------------------------------------------------------------------------
// parse

fn parse_command() cli.Command {
	mut flags := input_flags()
	flags << cli.Flag{
		flag:          .string
		name:          'output'
		abbrev:        'o'
		description:   'The desired parse output: ast, ast-human, events, data (default)'
		default_value: ['data']
	}
	return cli.Command{
		name:            'parse'
		description:     'Display the result of parsing Alda source code'
		man_description: 'Display the result of parsing Alda source code

${source_input_options('parse')}

The -o / --output parameter determines what output is displayed:

  ast        The AST that results from parsing the source code, as JSON.
  ast-human  The AST, displayed in a more human-readable way.
  events     A JSON array of the "events" parsed from the source code.
  data       (default) A JSON object representing the score that is
             constructed by evaluating the events in a new score.'
		posix_mode:      true
		flags:           flags
		execute:         report_errors(run_parse)
	}
}

fn run_parse(cmd cli.Command) ! {
	output := cmd.flags.get_string('output') or { 'data' }
	if output !in ['ast', 'ast-human', 'events', 'data'] {
		return error('${output} is not a supported output type.

Please choose one of: ast, ast-human, events, data')
	}

	input := read_input(cmd, 'parse')!
	ast := parser.parse(input.filename, input.code)!

	match output {
		'ast' {
			println(model.encode_json(ast.json()))
		}
		'ast-human' {
			println(ast.human_readable())
		}
		else {
			updates := ast.updates()!
			if output == 'events' {
				println(model.encode_json(json2.Any(updates.map(it.json()))))
				return
			}
			mut score := model.new_score()
			score.update(...updates)!
			println(model.encode_json(score.json()))
		}
	}
}

// ---------------------------------------------------------------------------
// export

fn export_command() cli.Command {
	mut flags := input_flags()
	flags << string_flag('from', 'F', 'Time marking (e.g. 0:30) or marker to start from')
	flags << string_flag('to', 'T', 'Time marking (e.g. 1:00) or marker to end at')
	flags << string_flag('output', 'o', 'The output filename (default: stdout)')
	flags << cli.Flag{
		flag:          .string
		name:          'output-format'
		abbrev:        'O'
		description:   'The output format: midi (default) or wav'
		default_value: ['midi']
	}
	flags << cli.Flag{
		flag:          .int
		name:          'midi-format'
		abbrev:        'M'
		description:   'MIDI file format: 0 (single track, Alda-compatible) or 1 (one track per part)'
		default_value: ['0']
	}
	return cli.Command{
		name:            'export'
		description:     'Evaluate Alda source code and export to another format'
		man_description: 'Evaluate Alda source code and export to another format

${source_input_options('export')}

When -o / --output FILENAME is provided, the results are written into that
file. Otherwise, the results are written to stdout.

Output formats: midi (a Standard MIDI File), wav (audio rendered offline
with the built-in synthesizer; requires a SoundFont).

MIDI files are format 0 (a single track) by default, as in Alda. Use
-M 1 / --midi-format 1 for a format 1 file with a tempo track and one named
track per part, which DAWs show as separate tracks:
  valda export -f my-score.alda -M 1 -o my-score.mid'
		posix_mode:      true
		flags:           flags
		execute:         report_errors(run_export)
	}
}

fn run_export(cmd cli.Command) ! {
	format := cmd.flags.get_string('output-format') or { 'midi' }
	if format !in ['midi', 'wav'] {
		return error('${format} is not a supported output format.

Supported output formats: midi, wav')
	}

	midi_format := cmd.flags.get_int('midi-format') or { 0 }
	if midi_format !in [0, 1] {
		return error('${midi_format} is not a supported MIDI file format.

Supported MIDI file formats: 0 (single track), 1 (one track per part)')
	}

	input := read_input(cmd, 'export')!
	from := cmd.flags.get_string('from') or { '' }
	to := cmd.flags.get_string('to') or { '' }
	output := cmd.flags.get_string('output') or { '' }

	score := build_score(input)!
	msgs := playback.score_messages(score, from: from, to: to)!

	data := if format == 'midi' {
		smf.encode(msgs, format: midi_format)
	} else {
		sf := find_soundfont(soundfont_flag(cmd))!
		engine.open_offline(sf, engine.default_sample_rate)!
		bytes := playback.render_wav(msgs, 3000)
		engine.close()
		bytes
	}

	if output != '' {
		os.write_file_array(output, data)!
		eprintln('Exported score to ${output}')
	} else {
		mut stdout := os.stdout()
		stdout.write(data)!
		stdout.flush()
	}
}

// ---------------------------------------------------------------------------
// import

fn import_command() cli.Command {
	return cli.Command{
		name:            'import'
		description:     'Import Alda source code from other formats'
		man_description: 'Import Alda source code from other formats

Currently, the only supported import format is MusicXML (score-partwise).

  valda import -i musicxml -f path/to/my-score.musicxml -o my-score.alda
  valda import -i musicxml -c "...some musicxml data..." -o my-score.alda
  cat my-score.musicxml | valda import -i musicxml > my-score.alda'
		posix_mode:      true
		flags:           [
			string_flag('file', 'f', 'Read data from a file to convert to Alda'),
			string_flag('code', 'c', 'Read data from a string to convert to Alda'),
			string_flag('output', 'o', 'The output Alda code filename (default: stdout)'),
			string_flag('import-format', 'i', 'The format of the imported data (musicxml)'),
		]
		execute:         report_errors(run_import)
	}
}

fn run_import(cmd cli.Command) ! {
	format := cmd.flags.get_string('import-format') or { '' }
	if format != 'musicxml' {
		return error('Provided ${format} is not a supported input format.

Currently, the only supported input format is musicxml.')
	}

	input := read_input(cmd, 'import')!
	updates := musicxml.import_musicxml(input.code)!
	root := parser.generate_ast(updates) or {
		return error('Issue generating Alda AST: ${err.msg()}.')
	}
	text := parser.format_ast(root) or {
		return error('Issue formatting imported Alda: ${err.msg()}.')
	}

	output := cmd.flags.get_string('output') or { '' }
	if output == '' {
		print(text)
	} else {
		os.write_file(output, text)!
		eprintln('Imported score to ${output}.')
	}
}

// ---------------------------------------------------------------------------
// format

fn format_command() cli.Command {
	return cli.Command{
		name:            'format'
		description:     'Format Alda source code (experimental)'
		man_description: 'Format Alda source code (experimental; comments are dropped)

  valda format -f path/to/my-score.alda
  valda format -f path/to/my-score.alda -o     (overwrite the file)
  valda format -f path/to/my-score.alda -w 120 -i "    "'
		posix_mode:      true
		flags:           [
			string_flag('file', 'f', 'Input Alda file to format'),
			cli.Flag{
				flag:        .bool
				name:        'overwrite'
				abbrev:      'o'
				description: 'Overwrite input file with formatted output'
			},
			cli.Flag{
				flag:          .int
				name:          'wrap'
				abbrev:        'w'
				description:   'Line length at which to wrap formatted output'
				default_value: ['80']
			},
			string_flag('indent', 'i', 'Indent text (default: two spaces)'),
		]
		execute:         report_errors(run_format)
	}
}

fn run_format(cmd cli.Command) ! {
	eprintln('WARN The format command is currently experimental. All comments are dropped during formatting.')

	file := cmd.flags.get_string('file') or { '' }
	if file == '' {
		return error('Please specify the file to format with -f / --file.')
	}
	wrap := cmd.flags.get_int('wrap') or { 80 }
	if wrap <= 0 {
		return error('Configured line wrap length ${wrap} must be positive.')
	}
	mut indent := cmd.flags.get_string('indent') or { '' }
	if indent == '' {
		indent = '  '
	}

	root := parser.parse_file(file)!
	text := parser.format_ast(root, soft_wrap_len: wrap, indent_text: indent) or {
		return error('Issue formatting Alda: ${err.msg()}.')
	}

	if cmd.flags.get_bool('overwrite') or { false } {
		os.write_file(file, text)!
	} else {
		print(text)
	}
}

// ---------------------------------------------------------------------------
// repl

fn repl_command() cli.Command {
	return cli.Command{
		name:            'repl'
		description:     'Start an Alda REPL client/server'
		man_description: 'Start an Alda REPL client/server

Examples:

  valda repl
    Equivalent to `valda repl --client --server`.

  valda repl --client --server
    Starts an interactive REPL session where the server is running in the
    background.

  valda repl --client --port 12345
    Starts an interactive REPL session that connects to an existing REPL
    server running on port 12345.

  valda repl --server --port 12345
    Starts a REPL server without an interactive prompt. Clients (including
    Alda editor integrations) can then connect via nREPL.

  valda repl --server --host 0.0.0.0 --port 12345
    Starts a REPL server that accepts connections from other machines, e.g.
    from outside a Docker container. Anyone who can reach the port can play
    and export scores, so only do this on a network you trust.

  valda repl --port 12345 --message \'{"op": "eval-and-play", "code": "banjo: c"}\'
    Sends an nREPL message to the REPL server running on port 12345.'
		posix_mode:      true
		flags:           [
			cli.Flag{
				flag:          .string
				name:          'host'
				abbrev:        'H'
				description:   'The hostname of the REPL server (with --server: the address to listen on)'
				default_value: ['127.0.0.1']
			},
			cli.Flag{
				flag:        .int
				name:        'port'
				abbrev:      'p'
				description: 'The port of the REPL server'
			},
			cli.Flag{
				flag:        .bool
				name:        'client'
				abbrev:      'c'
				description: 'Start a REPL client session'
			},
			cli.Flag{
				flag:        .bool
				name:        'server'
				abbrev:      's'
				description: 'Start a REPL server'
			},
			string_flag('message', 'm', 'A JSON nREPL message to send to the server'),
		]
		execute:         report_errors(run_repl)
	}
}

fn send_json_message(host string, port int, message string) ! {
	if port <= 0 {
		return error('You must specify the port of the REPL server (-p / --port).')
	}
	invalid := 'Invalid nREPL message:

  ${message}

Here is an example of a valid nREPL message:

  {"op": "eval-and-play", "code": "banjo: c"}'
	parsed := json2.decode[json2.Any](message) or { return error(invalid) }
	msg := repl.json_to_bvalue(parsed)
	if msg !is map[string]repl.BValue {
		return error(invalid)
	}
	request := msg as map[string]repl.BValue
	if 'op' !in request {
		return error(invalid)
	}
	res := repl.send_message(host, port, request)!
	println(model.encode_json(repl.bvalue_to_json(res)))
	if repl.response_errors(res).len > 0 {
		return error('The REPL server indicated that your request was unsuccessful.

See the response output for details.')
	}
}

fn run_repl(cmd cli.Command) ! {
	host := cmd.flags.get_string('host') or { '127.0.0.1' }
	mut port := cmd.flags.get_int('port') or { 0 }
	mut start_client := cmd.flags.get_bool('client') or { false }
	mut start_server := cmd.flags.get_bool('server') or { false }
	message := cmd.flags.get_string('message') or { '' }

	if message != '' {
		return send_json_message(host, port, message)
	}

	// With neither --client nor --server, run both.
	if !start_client && !start_server {
		start_client = true
		start_server = true
	}

	if !start_server {
		return connect_client(host, port)
	}

	mut audio := true
	open_audio(cmd) or {
		eprintln('WARN ${err.msg()}\n\nThe REPL server will run without audio.\n')
		audio = false
	}
	mut server := repl.new_server(audio)
	port = server.listen(if port > 0 { port } else { 0 }, host: host)!
	eprintln('nREPL server started on port ${port} on host ${host} - nrepl://${host}:${port}')
	if host !in ['127.0.0.1', 'localhost'] {
		eprintln('WARN The REPL server accepts connections from other machines. Anyone who can reach port ${port} can play and export scores.\n')
	}

	// NB: `defer` is block-scoped in V, so this must live at function level.
	defer {
		server.close()
		if audio {
			engine.close()
		}
	}

	for sig in [os.Signal.int, .term] {
		os.signal_opt(sig, fn [mut server] (_ os.Signal) {
			server.close()
			exit(0)
		}) or {}
	}

	if !start_client {
		// Serve until interrupted.
		for {
			time.sleep(time.hour)
		}
	}

	// A wildcard address can be listened on, but not connected to.
	connect_client(if host == '0.0.0.0' { '127.0.0.1' } else { host }, port)!
}

fn connect_client(host string, port int) ! {
	if port <= 0 {
		return error('You must specify the port of the REPL server you wish to connect to.

For example: valda repl --client --port 12345')
	}
	repl.run_client(host, port)!
}

// ---------------------------------------------------------------------------
// stop

fn stop_command() cli.Command {
	return cli.Command{
		name:            'stop'
		description:     'Stop playback in a running valda REPL server'
		man_description: 'Stop playback in a running valda REPL server

The port defaults to the one in the .alda-nrepl-port file in the current
directory, which REPL servers write on startup.'
		posix_mode:      true
		flags:           [
			cli.Flag{
				flag:        .int
				name:        'port'
				abbrev:      'p'
				description: 'The port of the REPL server'
			},
		]
		execute:         report_errors(run_stop)
	}
}

fn run_stop(cmd cli.Command) ! {
	mut port := cmd.flags.get_int('port') or { 0 }
	if port <= 0 {
		port_file := os.read_file('.alda-nrepl-port') or {
			return error('No REPL server port specified (-p / --port), and no .alda-nrepl-port file found.')
		}
		port = port_file.trim_space().int()
	}
	res := repl.send_message('127.0.0.1', port, {
		'op': repl.BValue('stop')
	})!
	errors := repl.response_errors(res)
	if errors.len > 0 {
		return error(errors.join('\n'))
	}
}

// ---------------------------------------------------------------------------
// instruments, version

fn instruments_command() cli.Command {
	return cli.Command{
		name:        'instruments'
		description: 'Display the list of available instruments'
		execute:     fn (_ cli.Command) ! {
			println(model.instruments_list().join('\n'))
		}
	}
}

// Where to get valda's source code. EPL-2.0 (section 3.1) requires binary
// distributions to say how to obtain it.
const source_url = 'https://github.com/CHANGE-ME/valda'

const license_notice = 'Copyright © 2026 Rodrigo Abt
Based on Alda (https://alda.io), copyright © 2012-2026 Dave Yarwood et al.

Distributed under the Eclipse Public License 2.0, without warranty of any kind.
The source code is available under the same license at ${source_url}
Third-party licenses: see the NOTICE file in the source distribution.'

fn version_command() cli.Command {
	return cli.Command{
		name:        'version'
		description: 'Print valda version information'
		execute:     fn (_ cli.Command) ! {
			println('valda ${repl.version}')
			println(license_notice)
		}
	}
}
