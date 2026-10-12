module model

import math
import regex

// ScoreUpdate is implemented by events that update a score.
pub type ScoreUpdate = AtMarker
	| AttributeUpdate
	| Barline
	| Chord
	| Cram
	| EventSequence
	| GlobalAttributeUpdate
	| LispList
	| LispNil
	| Marker
	| Note
	| OnRepetitions
	| PartDeclaration
	| Repeat
	| Rest
	| VariableDefinition
	| VariableReference
	| VoiceGroupEndMarker
	| VoiceMarker

// A Score is a data structure representing a musical score.
//
// Scores are built up via events (ScoreUpdates) that update aspects of the
// score data.
@[heap]
pub struct Score {
pub mut:
	parts             []&Part
	current_parts     []&Part
	aliases           map[string][]&Part
	events            []NoteEvent
	global_attributes GlobalAttributes
	markers           map[string]f64
	variables         map[string][]ScoreUpdate
mut:
	midi_channel_usage [16][]&Part
	part_counter       int
	// When true, notes/rests added to the score are placed at the same offset.
	// Otherwise, they are appended sequentially.
	chord_mode bool
}

// new_score returns an initialized score.
pub fn new_score() &Score {
	return &Score{}
}

// same reports whether two part references point to the same part instance.
// (In V, `==` on references compares the values, not the pointers.)
@[inline]
pub fn same(a &Part, b &Part) bool {
	return voidptr(a) == voidptr(b)
}

@[inline]
pub fn part_key(p &Part) u64 {
	return u64(voidptr(p))
}

fn contains_part(parts []&Part, part &Part) bool {
	for p in parts {
		if same(p, part) {
			return true
		}
	}
	return false
}

// update applies a number of ScoreUpdates to a Score, short-circuiting and
// returning the first error that occurs.
pub fn (mut score Score) update(updates ...ScoreUpdate) ! {
	for u in updates {
		u.update_score(mut score) or { return source_error(u.source_context(), err) }
	}
}

pub fn (u ScoreUpdate) source_context() AldaSourceContext {
	return match u {
		AtMarker, AttributeUpdate, Barline, Chord, Cram, EventSequence, GlobalAttributeUpdate,
		LispList, LispNil, Marker, Note, OnRepetitions, PartDeclaration, Repeat, Rest,
		VariableDefinition, VariableReference, VoiceGroupEndMarker, VoiceMarker {
			u.source_context
		}
	}
}

pub fn (u ScoreUpdate) update_score(mut score Score) ! {
	match u {
		AtMarker { u.update_score(mut score)! }
		AttributeUpdate { u.update_score(mut score)! }
		Barline {}
		Chord { u.update_score(mut score)! }
		Cram { u.update_score(mut score)! }
		EventSequence { score.update(...u.events)! }
		GlobalAttributeUpdate { u.update_score(mut score)! }
		LispList { u.update_score(mut score)! }
		LispNil {}
		Marker { u.update_score(mut score)! }
		Note { add_note_or_rest(mut score, u)! }
		OnRepetitions { u.update_score(mut score)! }
		PartDeclaration { u.update_score(mut score)! }
		Repeat { u.update_score(mut score)! }
		Rest { add_note_or_rest(mut score, u)! }
		VariableDefinition { u.update_score(mut score)! }
		VariableReference { u.update_score(mut score)! }
		VoiceGroupEndMarker { u.update_score(mut score)! }
		VoiceMarker { u.update_score(mut score)! }
	}
}

// duration_ms returns how long an event takes, in the context of a part. Used
// by Cram expressions, which sum the durations of their events and then
// time-scale them into a fixed duration. Can mutate the part (e.g. the default
// duration), so callers pass a copy.
pub fn (u ScoreUpdate) duration_ms(mut part Part) f64 {
	match u {
		Chord {
			mut shortest := math.max_f64
			for event in u.events {
				d := event.duration_ms(mut part)
				// Octave changes can be chord events, and they have no duration.
				if d > 0 && d < shortest {
					shortest = d
				}
			}
			return shortest
		}
		Cram {
			return effective_duration(u.duration, part).ms(part.tempo)
		}
		EventSequence {
			mut total := 0.0
			for event in u.events {
				total += event.duration_ms(mut part)
			}
			return total
		}
		LispList {
			// If evaluation fails, the error surfaces again in update_score.
			result := u.eval() or { return 0 }
			return unpack_score_update(result).duration_ms(mut part)
		}
		Note {
			d := effective_duration(u.duration, part).ms(part.tempo)
			update_default_duration(mut part, u.duration)
			return d
		}
		OnRepetitions {
			if u.applies_to(part.current_repetition) {
				return u.event.duration_ms(mut part)
			}
			return 0
		}
		Repeat {
			mut total := 0.0
			previous := part.current_repetition
			for repetition in 1 .. u.times + 1 {
				part.current_repetition = repetition
				total += u.event.duration_ms(mut part)
			}
			part.current_repetition = previous
			return total
		}
		Rest {
			d := effective_duration(u.duration, part).ms(part.tempo)
			update_default_duration(mut part, u.duration)
			return d
		}
		VariableReference {
			events := part.score.get_variable(u.variable_name) or { return 0 }
			mut total := 0.0
			for event in events {
				total += event.duration_ms(mut part)
			}
			return total
		}
		else {
			return 0
		}
	}
}

// variable_value returns the value that is captured when an event is part of a
// variable definition.
pub fn (u ScoreUpdate) variable_value(score &Score) !ScoreUpdate {
	match u {
		Chord {
			return Chord{
				source_context: u.source_context
				events:         variable_values(u.events, score)!
			}
		}
		Cram {
			return Cram{
				source_context: u.source_context
				events:         variable_values(u.events, score)!
				duration:       u.duration
			}
		}
		EventSequence {
			return EventSequence{
				source_context: u.source_context
				events:         variable_values(u.events, score)!
			}
		}
		LispList {
			result := u.eval()!
			return unpack_score_update(result).variable_value(score)
		}
		OnRepetitions {
			return OnRepetitions{
				source_context: u.source_context
				repetitions:    u.repetitions
				event:          u.event.variable_value(score)!
			}
		}
		PartDeclaration {
			return error('a part declaration cannot be part of a variable definition')
		}
		Repeat {
			return Repeat{
				source_context: u.source_context
				event:          u.event.variable_value(score)!
				times:          u.times
			}
		}
		VariableDefinition {
			return VariableDefinition{
				source_context: u.source_context
				variable_name:  u.variable_name
				events:         variable_values(u.events, score)!
			}
		}
		VariableReference {
			events := score.get_variable(u.variable_name)!
			return EventSequence{
				events: events
			}
		}
		else {
			return u
		}
	}
}

fn variable_values(events []ScoreUpdate, score &Score) ![]ScoreUpdate {
	mut values := []ScoreUpdate{cap: events.len}
	for event in events {
		values << event.variable_value(score)!
	}
	return values
}

// tracks returns a map of part (keyed by part_key of the origin part) to track
// number, for the purposes of playback.
pub fn (score &Score) tracks() map[u64]int {
	mut tracks := map[u64]int{}
	for i, part in score.parts {
		tracks[part_key(part.origin)] = i + 1
	}
	return tracks
}

// part_offsets returns a map of part IDs to their current (effective) offsets.
pub fn (score &Score) part_offsets() map[string]f64 {
	mut offsets := map[string]f64{}
	for part in score.parts {
		offsets[part.origin.id] = part.origin.calculate_effective_offset()
	}
	return offsets
}

// interpret_offset_reference interprets a string as a specific offset in the
// score in milliseconds. Valid references are minute-and-second time markings
// (e.g. "0:30") and names of markers defined in the score.
pub fn (score &Score) interpret_offset_reference(reference string) !f64 {
	mut re := regex.regex_opt(r'^(\d+):(\d+)$') or { panic(err) }
	if re.matches_string(reference) {
		parts := reference.split(':')
		return f64(parts[0].int() * 60 * 1000) + f64(parts[1].int() * 1000)
	}

	return score.markers[reference] or {
		return error('${reference} is not a valid offset reference.

Valid offset references include:
  • A minute-and-second time marking (e.g. 0:30)
  • The name of a marker in the score (e.g. verse2)')
	}
}

// TempoEntry is a tempo value that starts at an offset in the score.
pub struct TempoEntry {
pub:
	offset f64
	tempo  f64
}

// tempo_itinerary returns the "master" tempo changes over time, sorted by
// offset. It is derived from the tempo changes of the part whose role is the
// tempo master, plus global tempo changes. Used e.g. for MIDI export.
pub fn (score &Score) tempo_itinerary() []TempoEntry {
	mut itinerary := map[f64]f64{}
	itinerary[0.0] = 120.0

	for part in score.parts {
		if part.tempo_role != .master {
			continue
		}
		for offset, tempo in part.tempo_values {
			itinerary[offset] = tempo
		}
	}

	// For global metric modulation, assume the parts are at the tempo of the
	// last global tempo change (the same heuristic as Alda).
	mut last_global_tempo := 120.0
	for offset in score.global_attributes.offsets {
		for update in score.global_attributes.itinerary[offset] {
			match update {
				TempoSet {
					last_global_tempo = update.tempo
					itinerary[offset] = update.tempo
				}
				MetricModulation {
					itinerary[offset] = last_global_tempo * update.ratio
				}
				else {}
			}
		}
	}

	mut offsets := itinerary.keys()
	offsets.sort()
	return offsets.map(TempoEntry{ offset: it, tempo: itinerary[it] })
}
