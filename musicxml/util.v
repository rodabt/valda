module musicxml

import math
import model

fn warn_while_parsing(tag string, message string) {
	eprintln('WARN Issue parsing tag <${tag}>: ${message}')
}

fn warn(message string) {
	eprintln('WARN ${message}')
}

// get_nested_updates abstracts recursion over the nested updates in a score
// update. With `to_import`, repeats/endings that are complete (times or
// repetitions set) and chords are not considered importable.
fn get_nested_updates(update model.ScoreUpdate, to_import bool) ?[]model.ScoreUpdate {
	match update {
		model.Repeat {
			// A repeat's times tracks whether the repeat has ended.
			if to_import && update.times > 0 {
				return none
			}
			return events_of(update.event)
		}
		model.OnRepetitions {
			// An ending's repetitions track whether it has ended.
			if to_import && update.repetitions.len > 0 {
				return none
			}
			return events_of(update.event)
		}
		model.Chord {
			// We never import directly into a chord.
			if !to_import {
				return update.events
			}
		}
		model.EventSequence {
			return update.events
		}
		else {}
	}
	return none
}

fn events_of(update model.ScoreUpdate) []model.ScoreUpdate {
	if update is model.EventSequence {
		return update.events
	}
	return []
}

type ModifyFn = fn ([]model.ScoreUpdate) []model.ScoreUpdate

// modify_nested_updates returns the update with its nested updates modified,
// and whether it has nested updates at all.
fn modify_nested_updates(update model.ScoreUpdate, modify ModifyFn) (model.ScoreUpdate, bool) {
	match update {
		model.Repeat {
			return model.Repeat{
				...update
				event: model.EventSequence{
					events: modify(events_of(update.event))
				}
			}, true
		}
		model.OnRepetitions {
			return model.OnRepetitions{
				...update
				event: model.EventSequence{
					events: modify(events_of(update.event))
				}
			}, true
		}
		model.Chord {
			return model.Chord{
				...update
				events: modify(update.events)
			}, true
		}
		model.EventSequence {
			return model.EventSequence{
				...update
				events: modify(update.events)
			}, true
		}
		else {
			return update, false
		}
	}
}

fn set_nested_updates(update model.ScoreUpdate, updates []model.ScoreUpdate) model.ScoreUpdate {
	modified, _ := modify_nested_updates(update, fn [updates] (_ []model.ScoreUpdate) []model.ScoreUpdate {
		return updates
	})
	return modified
}

fn duration_beats(d model.Duration) f64 {
	return d.beats() or { 0 }
}

// get_beats counts beats for un-optimized updates.
fn get_beats(updates ...model.ScoreUpdate) f64 {
	mut beats := 0.0
	for update in updates {
		match update {
			model.Note {
				beats += duration_beats(update.duration)
			}
			model.Rest {
				beats += duration_beats(update.duration)
			}
			model.Chord {
				mut min := math.max_f64
				for event in update.events {
					// The minimum non-zero duration, i.e. a real note/rest.
					event_beats := get_beats(event)
					if event_beats > 0 && event_beats < min {
						min = event_beats
					}
				}
				if min < math.max_f64 {
					beats += min
				}
			}
			model.Repeat {
				beats += get_beats(update.event)
			}
			model.OnRepetitions {
				beats += get_beats(update.event)
			}
			model.EventSequence {
				beats += get_beats(...update.events)
			}
			else {}
		}
	}
	return beats
}

fn insert_at(update model.ScoreUpdate, updates []model.ScoreUpdate, index int) []model.ScoreUpdate {
	mut result := updates.clone()
	result.insert(index, update)
	return result
}

fn remove_trailing_barline(d model.Duration) ?model.Duration {
	if d.components.len > 0 && d.components.last() is model.Barline {
		return model.Duration{
			components: d.components[..d.components.len - 1].clone()
		}
	}
	return none
}

// standardize_barlines moves barlines that are the last duration component of
// a note or rest to directly after it. Equivalent Alda, but easier to process.
fn standardize_barlines(input []model.ScoreUpdate) []model.ScoreUpdate {
	mut updates := input.clone()
	for i := updates.len - 1; i >= 0; i-- {
		original := updates[i]
		mut update := original
		mut barline_after := false

		match original {
			model.Note {
				if d := remove_trailing_barline(original.duration) {
					update = model.Note{
						...original
						duration: d
					}
					barline_after = true
				}
			}
			model.Rest {
				if d := remove_trailing_barline(original.duration) {
					update = model.Rest{
						...original
						duration: d
					}
					barline_after = true
				}
			}
			else {}
		}

		updates[i] = update
		if barline_after {
			updates = insert_at(model.Barline{}, updates, i + 1)
		}

		modified, ok := modify_nested_updates(update, standardize_barlines)
		if ok {
			updates[i] = modified
		}
	}
	return updates
}

fn is_duration_update(update model.ScoreUpdate) bool {
	return update is model.Note || update is model.Rest || update is model.Chord
}

// filter_nested_importable_update finds the (nested) update to import into.
fn filter_nested_importable_update(update model.ScoreUpdate) bool {
	if nested := get_nested_updates(update, true) {
		if nested.len == 0 {
			return true
		}
		// Stop if the nested layer has no further importable layers.
		if _ := get_nested_updates(nested.last(), true) {
			return false
		}
		return true
	}
	return false
}

fn is_repeat(update model.ScoreUpdate) bool {
	return update is model.Repeat
}

fn percussion_part_name_to_alias(name string) string {
	return name.split(' ').join('_')
}

const note_letter_intervals = {
	model.NoteLetter.c: 0
	.d:                 2
	.e:                 4
	.f:                 5
	.g:                 7
	.a:                 9
	.b:                 11
}

// to_letter_and_accidentals_and_octave naively translates a MIDI note number
// to a note letter with no accidentals or sharps, plus an octave.
fn to_letter_and_accidentals_and_octave(number model.MidiNoteNumber) (model.LetterAndAccidentals, int) {
	quotient := (number.midi_note - 24) / 12
	remainder := (number.midi_note - 24) % 12
	octave := quotient + 1

	mut letter := model.NoteLetter.c
	for l, interval in note_letter_intervals {
		if interval <= remainder && interval > note_letter_intervals[letter] {
			letter = l
		}
	}

	mut sharps := []model.Accidental{}
	for _ in note_letter_intervals[letter] .. remainder {
		sharps << .sharp
	}

	return model.LetterAndAccidentals{
		note_letter:     letter
		accidentals:     sharps
		has_accidentals: sharps.len > 0
	}, octave
}

fn note_or_rest_duration(update model.ScoreUpdate) model.Duration {
	return match update {
		model.Note { update.duration }
		model.Rest { update.duration }
		else { model.Duration{} }
	}
}

fn set_note_or_rest_duration(update model.ScoreUpdate, d model.Duration) model.ScoreUpdate {
	return match update {
		model.Note {
			model.ScoreUpdate(model.Note{
				...update
				duration: d
			})
		}
		model.Rest {
			model.ScoreUpdate(model.Rest{
				...update
				duration: d
			})
		}
		else {
			update
		}
	}
}

fn is_or_contains_barline(update model.ScoreUpdate) bool {
	if update is model.Barline {
		return true
	}
	for component in note_or_rest_duration(update).components {
		if component is model.Barline {
			return true
		}
	}
	return false
}

fn durations_equal(a model.Duration, b model.Duration) bool {
	if a.components.len != b.components.len {
		return false
	}
	for i, ca in a.components {
		cb := b.components[i]
		if ca.type_name() != cb.type_name() {
			return false
		}
		if ca is model.NoteLength && cb is model.NoteLength {
			if ca.denominator != cb.denominator || ca.dots != cb.dots {
				return false
			}
		} else if ca.json().str() != cb.json().str() {
			return false
		}
	}
	return true
}

// idiomatic_duration applies simple heuristics to make durations idiomatic,
// e.g. decomposing 4/3 into a dotted half note.
fn idiomatic_duration(duration f64, dots int) model.Duration {
	alda_duration := round_if_close_enough(duration)

	// Actual dotted notes are preserved, to avoid confusion.
	if dots == 0 {
		normal := [1.0, 2, 4, 8, 16]

		mut remaining := alda_duration
		mut decomp := map[f64]int{}
		mut i := 0
		for i < normal.len {
			if math.abs(remaining - normal[i]) < 0.01 {
				decomp[normal[i]]++
				remaining = 0
				break
			} else if remaining < normal[i] {
				decomp[normal[i]]++
				remaining = 1 / ((1 / remaining) - (1 / normal[i]))
			} else {
				i++
			}
		}

		if remaining == 0 {
			// Represent a two-part decomposition as a single dotted duration.
			if decomp.len == 2 {
				for j := 0; j + 1 < normal.len; j++ {
					if decomp[normal[j]] == 1 && decomp[normal[j + 1]] == 1 {
						return model.Duration{
							components: [
								model.DurationComponent(model.NoteLength{
									denominator: normal[j]
									dots:        1
								}),
							]
						}
					}
				}
			}

			// Otherwise, tie together each decomposed normal duration.
			mut components := []model.DurationComponent{}
			for d in normal {
				for _ in 0 .. decomp[d] {
					components << model.NoteLength{
						denominator: d
					}
				}
			}
			return model.Duration{
				components: components
			}
		}
	}

	return model.Duration{
		components: [
			model.DurationComponent(model.NoteLength{
				denominator: alda_duration
				dots:        dots
			}),
		]
	}
}

// round_if_close_enough deals with floating point arithmetic issues.
fn round_if_close_enough(val f64) f64 {
	if math.abs(val - math.round(val)) < 0.0001 {
		return math.round(val)
	}
	return val
}
