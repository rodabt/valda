module model

import math

fn approx(a f64, b f64) bool {
	return math.abs(a - b) < 1e-6
}

fn note(letter NoteLetter) ScoreUpdate {
	return Note{
		pitch: LetterAndAccidentals{
			note_letter: letter
		}
	}
}

fn note_len(letter NoteLetter, denominator f64) ScoreUpdate {
	return Note{
		pitch:    LetterAndAccidentals{
			note_letter: letter
		}
		duration: Duration{
			components: [
				DurationComponent(NoteLength{
					denominator: denominator
				}),
			]
		}
	}
}

fn part_decl(names ...string) ScoreUpdate {
	return PartDeclaration{
		names: names
	}
}

fn offsets(score &Score) []f64 {
	return score.events.map(it.offset)
}

fn test_note_length_beats() {
	assert approx(NoteLength{ denominator: 4 }.beats(), 1)
	assert approx(NoteLength{ denominator: 2, dots: 1 }.beats(), 3)
	assert approx(NoteLength{ denominator: 2, dots: 2 }.beats(), 3.5)
	assert approx(NoteLength{ denominator: 6 }.beats(), 2.0 / 3)
}

fn test_duration_ms() {
	d := Duration{
		components: [DurationComponent(NoteLength{
			denominator: 4
		}), NoteLengthMs{
			quantity: 250
		}, NoteLengthSeconds{
			quantity: 1
		}]
	}
	assert approx(d.ms(120), 500 + 250 + 1000)
}

fn test_midi_note_calculation() {
	c := PitchIdentifier(LetterAndAccidentals{
		note_letter: .c
	})
	assert c.calculate_midi_note(4, KeySignature{}, 0) == 60
	assert c.calculate_midi_note(4, KeySignature{}, 2) == 62

	f_sharp := key_signature_from_scale(LetterAndAccidentals{ note_letter: .g }, .ionian)
	f := PitchIdentifier(LetterAndAccidentals{
		note_letter: .f
	})
	assert f.calculate_midi_note(4, f_sharp, 0) == 66

	// Explicit accidentals override the key signature.
	f_natural := PitchIdentifier(LetterAndAccidentals{
		note_letter:     .f
		accidentals:     [.natural]
		has_accidentals: true
	})
	assert f_natural.calculate_midi_note(4, f_sharp, 0) == 65
	assert PitchIdentifier(MidiNoteNumber{
		midi_note: 42
	}).calculate_midi_note(4, f_sharp, 1) == 43
}

fn test_key_signatures() {
	assert key_signature_from_scale(LetterAndAccidentals{ note_letter: .c }, .ionian).str() == ''
	assert key_signature_from_scale(LetterAndAccidentals{ note_letter: .a }, .ionian).str() == 'f+ c+ g+'
	assert key_signature_from_scale(LetterAndAccidentals{ note_letter: .g }, .aeolian).str() == 'b- e-'
	assert key_signature_from_scale(LetterAndAccidentals{ note_letter: .d }, .dorian).str() == ''
	assert key_signature_from_scale(LetterAndAccidentals{
		note_letter:     .c
		accidentals:     [.sharp]
		has_accidentals: true
	}, .ionian).str() == 'f+ c+ g+ d+ a+ e+ b+'
	assert key_signature_from_circle_of_fifths(-2).str() == 'b- e-'
	// Sharpening Bb major (2 flats) gives B major (5 sharps).
	assert key_signature_from_circle_of_fifths(-2).sharpen().str() == 'f+ c+ g+ d+ a+'
}

fn test_notes_are_sequential_and_durations_sticky() {
	mut score := new_score()
	score.update(part_decl('piano'), note_len(.c, 8), note(.d), note_len(.e, 2), note(.f))!
	assert offsets(score) == [0.0, 250, 500, 1500]
	assert score.events.map(it.midi_note) == [60, 62, 64, 65]
	// Default quantization is 90%.
	assert approx(score.events[0].audible_duration, 225)
}

fn test_chords_advance_by_shortest_note() {
	mut score := new_score()
	score.update(part_decl('piano'), Chord{
		events: [note_len(.c, 1), note_len(.e, 4), note_len(.g, 2)]
	}, note(.c))!
	assert offsets(score) == [0.0, 0, 0, 500]
}

fn test_cram() {
	mut score := new_score()
	score.update(part_decl('piano'), Cram{
		events:   [note(.c), note(.d), note(.e)]
		duration: Duration{
			components: [DurationComponent(NoteLength{
				denominator: 2
			})]
		}
	}, note(.f))!
	o := offsets(score)
	assert approx(o[1], 1000.0 / 3)
	assert approx(o[2], 2000.0 / 3)
	// The cram's duration becomes the default.
	assert approx(o[3], 1000)
}

fn test_repeats_and_repetitions() {
	mut score := new_score()
	score.update(part_decl('piano'), Repeat{
		times: 3
		event: EventSequence{
			events: [note(.c), OnRepetitions{
				repetitions: [RepetitionRange{2, 3}]
				event:       note(.d)
			}]
		}
	})!
	assert score.events.map(it.midi_note) == [60, 60, 62, 60, 62]
}

fn test_variables_capture_values() {
	mut score := new_score()
	score.update(part_decl('piano'), VariableDefinition{
		variable_name: 'x'
		events:        [note(.c), note(.e)]
	}, VariableDefinition{
		variable_name: 'y'
		events:        [VariableReference{
			variable_name: 'x'
		}, note(.g)]
	}, VariableReference{
		variable_name: 'y'
	})!
	assert score.events.map(it.midi_note) == [60, 64, 67]

	score.update(VariableReference{ variable_name: 'nope' }) or {
		assert err.msg().contains('undefined variable: nope')
		return
	}
	assert false
}

fn test_voices_continue_from_last_to_finish() {
	mut score := new_score()
	score.update(part_decl('piano'), VoiceMarker{
		voice_number: 1
	}, note_len(.c, 1), VoiceMarker{
		voice_number: 2
	}, note_len(.e, 4), VoiceGroupEndMarker{}, note(.g))!
	assert offsets(score) == [0.0, 0, 2000]
}

fn test_markers() {
	mut score := new_score()
	score.update(part_decl('piano'), note(.c), Marker{
		name: 'here'
	}, note(.d), part_decl('violin'), AtMarker{
		name: 'here'
	}, note(.e))!
	assert offsets(score) == [0.0, 500, 500]
	assert score.interpret_offset_reference('here')! == 500
	assert score.interpret_offset_reference('1:30')! == 90000
	if _ := score.interpret_offset_reference('nowhere') {
		assert false
	}
}

fn test_global_attributes_apply_to_all_parts() {
	mut score := new_score()
	score.update(part_decl('piano'), note(.c), GlobalAttributeUpdate{
		part_update: TempoSet{
			tempo: 60
		}
	}, note(.d), note(.e), part_decl('violin'), note(.c), note(.d), note(.e))!
	// Both parts switch to 60 bpm at 500ms.
	assert offsets(score) == [0.0, 500, 1500, 0, 500, 1500]
	tempos := score.tempo_itinerary()
	assert tempos.len == 2 && tempos[1].offset == 500 && tempos[1].tempo == 60
}

fn test_midi_channels() {
	mut score := new_score()
	score.update(part_decl('piano'), note(.c), part_decl('violin'), note(.c), part_decl('percussion'),
		note(.c))!
	assert score.events.map(it.midi_channel) == [0, 1, 9]
}

fn test_part_aliases_and_groups() {
	mut score := new_score()
	score.update(PartDeclaration{
		names: ['piano']
		alias: 'foo'
	}, PartDeclaration{
		names: ['trumpet']
		alias: 'bar'
	}, PartDeclaration{
		names: ['foo', 'bar']
		alias: 'both'
	}, note(.c))!
	assert score.events.len == 2
	assert 'both.foo' in score.aliases && 'both.piano' in score.aliases

	score.update(PartDeclaration{
		names: ['piano']
	}) or {
		assert err.msg().contains('ambiguous instrument reference')
		return
	}
	assert false
}

fn test_lisp_attributes() {
	mut score := new_score()
	score.update(part_decl('piano'), LispList{
		elements: [LispForm(LispSymbol{
			name: 'tempo'
		}), LispNumber{
			value: 60
		}]
	}, LispList{
		elements: [LispForm(LispSymbol{
			name: 'key-sig'
		}), LispString{
			value: 'f+'
		}]
	}, LispList{
		elements: [LispForm(LispSymbol{
			name: 'vol'
		}), LispNumber{
			value: 50
		}]
	}, note(.f))!
	e := score.events[0]
	assert e.midi_note == 66
	assert approx(e.duration, 1000)
	assert approx(e.volume, 0.5)
}

fn test_lisp_signature_errors() {
	form := LispForm(LispList{
		elements: [LispForm(LispSymbol{
			name: 'octave'
		}), LispString{
			value: 'x'
		}]
	})
	form.eval() or {
		assert err.msg().contains('provided arguments do not match the signature of `octave`')
		return
	}
	assert false
}

fn test_parse_note_length() {
	nl := parse_note_length('2..')!
	assert nl.denominator == 2 && nl.dots == 2
	assert parse_note_length('1.5')!.denominator == 1.5
	if _ := parse_note_length('x') {
		assert false
	}
}

fn test_json_encoding_matches_go() {
	assert format_number(4) == '4'
	assert format_number(0.5421) == '0.5421'
	assert format_number(-1) == '-1'
	assert encode_json(obj(s('b'), s('<fn>'), s('a'), f(1.5))) == '{"a":1.5,"b":"\\u003cfn\\u003e"}'
}
