module main

import cli
import engine
import model
import parser
import playback
import repl
import smf

fn doctor_command() cli.Command {
	return cli.Command{
		name:        'doctor'
		description: 'Check that valda can run correctly'
		posix_mode:  true
		execute:     report_errors(run_doctor)
	}
}

@[heap]
struct DoctorState {
mut:
	soundfont string
}

struct Check {
	description string
	run         fn () !string @[required]
}

fn run_doctor(cmd cli.Command) ! {
	sf_flag := soundfont_flag(cmd)
	// Shared between checks (closures capture copies of plain values).
	mut state := &DoctorState{}

	checks := [
		Check{'Parse source code', fn () !string {
			parser.parse_string('piano: c d e f g')!
			return ''
		}},
		Check{'Generate score model', fn () !string {
			mut score := model.new_score()
			score.update(...parser.parse_updates('', 'piano: (tempo 90) c8 d e f g2')!)!
			if score.events.len != 5 {
				return error('expected 5 note events, got ${score.events.len}')
			}
			return ''
		}},
		Check{'Export a MIDI file', fn () !string {
			mut score := model.new_score()
			score.update(...parser.parse_updates('', 'piano: c d e')!)!
			data := smf.encode(playback.score_messages(score)!)
			if data.len < 30 || data[..4].bytestr() != 'MThd' {
				return error('invalid MIDI data')
			}
			return '${data.len} bytes'
		}},
		Check{'Find a SoundFont', fn [sf_flag, mut state] () !string {
			state.soundfont = find_soundfont(sf_flag)!
			return state.soundfont
		}},
		Check{'Render audio offline', fn [state] () !string {
			if state.soundfont == '' {
				return error('skipped (no SoundFont)')
			}
			engine.open_offline(state.soundfont, 22050)!
			defer {
				engine.close()
			}
			mut score := model.new_score()
			score.update(...parser.parse_updates('', 'piano: c4')!)!
			wav := playback.render_wav(playback.score_messages(score)!, 500)
			mut peak := 0
			for i := 44; i + 1 < wav.len; i += 2 {
				sample := int(i16(u16(wav[i]) | (u16(wav[i + 1]) << 8)))
				if sample > peak {
					peak = sample
				} else if -sample > peak {
					peak = -sample
				}
			}
			if peak == 0 {
				return error('the rendered audio is silent')
			}
			return 'peak amplitude ${peak}'
		}},
		Check{'Open the audio device', fn [state] () !string {
			if state.soundfont == '' {
				return error('skipped (no SoundFont)')
			}
			engine.open(state.soundfont)!
			backend := engine.backend()
			engine.close()
			return 'backend: ${backend}'
		}},
		Check{'Start a REPL server and connect to it', fn () !string {
			mut server := repl.new_server(false)
			port := server.listen(0)!
			defer {
				server.close()
			}
			res := repl.send_message('127.0.0.1', port, {
				'op':   repl.BValue('load')
				'code': repl.BValue('piano: c d e')
			})!
			errors := repl.response_errors(res)
			if errors.len > 0 {
				return error(errors.join('; '))
			}
			return 'port ${port}'
		}},
	]

	mut failures := 0
	for check in checks {
		detail := check.run() or {
			failures++
			println('ERR  ${check.description}: ${err.msg()}')
			continue
		}
		suffix := if detail != '' { ' (${detail})' } else { '' }
		println('OK   ${check.description}${suffix}')
	}

	if failures > 0 {
		return error('\n${failures} check(s) failed.')
	}
}
