module musicxml

import model

// The optimizer generates more idiomatic Alda from imported updates: it
// removes redundant accidentals and durations, and translates MIDI note
// numbers (unpitched percussion) to letters and octaves.
@[heap]
struct Optimizer {
mut:
	// True if the last occurrence of a note had accidentals different from the
	// key signature, in which case the next "redundant" accidental is kept, to
	// reiterate the return to the key signature (as in sheet music).
	current_note_state map[int]bool
	// The last encountered duration and octave, reset in various situations
	// (nested structures, barlines) to keep complex structures intact.
	current_duration model.Duration
	current_octave   int = -1
	// The current key signature. Not soft-reset, because MusicXML import never
	// changes key signatures within a single voice.
	current_key_signature model.KeySignature
}

fn new_optimizer() &Optimizer {
	mut opt := &Optimizer{
		current_key_signature: model.key_signature_from_circle_of_fifths(0)
	}
	opt.soft_reset()
	return opt
}

fn (mut opt Optimizer) reset_note_state() {
	for letter in 0 .. 7 {
		opt.current_note_state[letter] = false
	}
}

fn (mut opt Optimizer) reset_duration() {
	opt.current_duration = model.Duration{}
}

fn (mut opt Optimizer) reset_octave() {
	opt.current_octave = -1
}

fn (mut opt Optimizer) soft_reset() {
	opt.reset_note_state()
	opt.reset_duration()
	opt.reset_octave()
}

fn accidentals_equal(a []model.Accidental, b []model.Accidental) bool {
	return a == b
}

fn key_signatures_equal(a model.KeySignature, b model.KeySignature) bool {
	if a.entries.len != b.entries.len {
		return false
	}
	for k, v in a.entries {
		other := b.entries[k] or { return false }
		if v != other {
			return false
		}
	}
	return true
}

fn (mut opt Optimizer) remove_redundant_accidentals(input []model.ScoreUpdate) []model.ScoreUpdate {
	mut updates := input.clone()
	for i, original in updates {
		mut update := original

		match original {
			model.AttributeUpdate {
				pu := original.part_update
				if pu is model.KeySignatureSet {
					if !key_signatures_equal(opt.current_key_signature, pu.key_signature) {
						opt.reset_note_state()
						opt.current_key_signature = pu.key_signature
					}
				}
			}
			model.Note {
				pitch := original.pitch
				if pitch is model.LetterAndAccidentals {
					letter := pitch.note_letter
					key_accidentals := opt.current_key_signature.accidentals(letter)

					if !accidentals_equal(pitch.accidentals, key_accidentals) {
						opt.current_note_state[int(letter)] = true
					} else if !opt.current_note_state[int(letter)] {
						// Redundant accidentals (covered by the key signature)
						update = model.Note{
							...original
							pitch: model.LetterAndAccidentals{
								note_letter: letter
							}
						}
					}
				}
			}
			else {}
		}

		if is_or_contains_barline(update) {
			opt.reset_note_state()
		}

		modified, ok := modify_nested_updates(update, opt.remove_redundant_accidentals)
		if ok {
			update = modified
		}

		updates[i] = update
	}
	return updates
}

// remove_redundant_durations removes repeated durations within a measure.
fn (mut opt Optimizer) remove_redundant_durations(input []model.ScoreUpdate) []model.ScoreUpdate {
	mut updates := input.clone()
	for i, original in updates {
		mut update := original

		if is_or_contains_barline(update) {
			opt.reset_duration()
		} else {
			d := note_or_rest_duration(update)
			if d.components.len > 0 {
				if opt.current_duration.components.len != 0
					&& durations_equal(opt.current_duration, d) {
					// A repeated duration
					update = set_note_or_rest_duration(update, model.Duration{})
				}
				opt.current_duration = d
			}
		}

		if _ := get_nested_updates(update, false) {
			opt.reset_duration()
			modified, _ := modify_nested_updates(update, opt.remove_redundant_durations)
			update = modified
			opt.reset_duration()
		}

		updates[i] = update
	}
	return updates
}

// translate_midi_note_pitches translates notes with MIDI note number pitches
// into letters and accidentals, inserting octave changes as needed.
fn (mut opt Optimizer) translate_midi_note_pitches(input []model.ScoreUpdate) []model.ScoreUpdate {
	mut updates := input.clone()
	mut octave_set_indices := []int{}
	mut octave_set_octaves := []int{}

	for i, original in updates {
		mut update := original

		if original is model.Note {
			pitch := original.pitch
			if pitch is model.MidiNoteNumber {
				laa, octave := to_letter_and_accidentals_and_octave(pitch)
				update = model.Note{
					...original
					pitch: laa
				}
				if octave != opt.current_octave {
					octave_set_indices << i
					octave_set_octaves << octave
					opt.current_octave = octave
				}
			}
		}

		if is_or_contains_barline(update) {
			opt.reset_octave()
		}

		if _ := get_nested_updates(update, false) {
			opt.reset_octave()
			modified, _ := modify_nested_updates(update, opt.translate_midi_note_pitches)
			update = modified
			opt.reset_octave()
		}

		updates[i] = update
	}

	for i := octave_set_indices.len - 1; i >= 0; i-- {
		updates = insert_at(model.AttributeUpdate{
			part_update: model.OctaveSet{
				octave_number: octave_set_octaves[i]
			}
		}, updates, octave_set_indices[i])
	}

	return updates
}

// handle_unfinished_repeats gives repeats that were never closed (times == 0)
// a times value of 1, to preserve the repeat information.
fn handle_unfinished_repeats(input []model.ScoreUpdate) []model.ScoreUpdate {
	mut updates := input.clone()
	for i, original in updates {
		mut update := original
		if original is model.Repeat && original.times == 0 {
			update = model.Repeat{
				...original
				times: 1
			}
		}
		if _ := get_nested_updates(update, false) {
			modified, _ := modify_nested_updates(update, handle_unfinished_repeats)
			update = modified
		}
		updates[i] = update
	}
	return updates
}

fn (mut opt Optimizer) optimize(input []model.ScoreUpdate) []model.ScoreUpdate {
	// standardize_barlines must come before remove_redundant_durations, and
	// translate_midi_note_pitches before remove_redundant_durations.
	mut updates := standardize_barlines(input)
	updates = opt.remove_redundant_accidentals(updates)
	updates = opt.translate_midi_note_pitches(updates)
	updates = opt.remove_redundant_durations(updates)
	updates = handle_unfinished_repeats(updates)

	// Reset so that subsequent voices have fresh starts.
	opt.soft_reset()
	return updates
}
