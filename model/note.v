module model

import math

// A Note represents a single pitch being sustained for a period of time.
pub struct Note {
pub mut:
	source_context AldaSourceContext
	pitch          PitchIdentifier
	duration       Duration
	// When a note is slurred, there is minimal space between it and the next.
	slurred bool
}

// A Rest represents a period of time spent waiting.
pub struct Rest {
pub:
	source_context AldaSourceContext
	duration       Duration
}

// A NoteEvent is a Note expressed in absolute terms, ready to be performed,
// e.g. by a MIDI synthesizer.
pub struct NoteEvent {
pub:
	part             &Part = unsafe { nil }
	midi_channel     int
	midi_note        int
	offset           f64
	duration         f64
	audible_duration f64
	volume           f64
	track_volume     f64
	panning          f64
}

fn effective_duration(specified Duration, part &Part) Duration {
	if !specified.is_specified() {
		return part.duration
	}
	return specified
}

// Note/rest duration is "sticky": subsequent notes/rests without a specified
// duration take on the duration of the part's last note/rest.
fn update_default_duration(mut part Part, d Duration) {
	if d.is_specified() {
		part.duration = d
	}
}

fn add_note_or_rest(mut score Score, note_or_rest ScoreUpdate) ! {
	// In a chord, global attributes are applied once by the chord itself.
	if !score.chord_mode {
		score.apply_global_attributes()!
	}

	specified := match note_or_rest {
		Note { note_or_rest.duration }
		Rest { note_or_rest.duration }
		else { Duration{} }
	}

	specified.validate()!

	for mut part in score.current_parts {
		d := effective_duration(specified, part)
		duration_ms := d.ms(part.tempo) * part.time_scale

		if note_or_rest is Note {
			mut audible_ms := duration_ms
			if !note_or_rest.slurred {
				audible_ms *= part.quantization
			}

			if audible_ms > 0 {
				midi_note := note_or_rest.pitch.calculate_midi_note(part.octave, part.key_signature,
					part.transposition)

				if midi_note < 0 || midi_note > 127 {
					return error('MIDI note out of the 0-127 range. Input note: ${midi_note}')
				}

				midi_channel := score.assign_midi_channel(part, audible_ms)!

				part.midi_channel = midi_channel
				mut origin := part.origin
				origin.midi_channel = midi_channel

				score.events << NoteEvent{
					part:             part.origin
					midi_channel:     midi_channel
					midi_note:        midi_note
					offset:           part.current_offset
					duration:         duration_ms
					audible_duration: audible_ms
					volume:           part.volume
					track_volume:     part.track_volume
					panning:          part.panning
				}
			}
		}

		if !score.chord_mode {
			part.last_offset = part.current_offset
			part.current_offset += duration_ms
		}

		update_default_duration(mut part, d)
	}
}

// A Chord is a collection of notes and rests starting at the same point in
// time. Other events (e.g. octave changes) may occur between the notes.
pub struct Chord {
pub:
	source_context AldaSourceContext
	events         []ScoreUpdate
}

pub fn (chord Chord) update_score(mut score Score) ! {
	score.apply_global_attributes()!

	mut shortest := map[u64]f64{}
	for part in score.current_parts {
		shortest[part_key(part)] = math.max_f64
	}

	score.chord_mode = true
	for event in chord.events {
		// Following a chord, the next note/rest is placed after the shortest
		// note/rest in the chord.
		specified := match event {
			Note { event.duration }
			Rest { event.duration }
			else { Duration{} }
		}

		for part in score.current_parts {
			d := effective_duration(specified, part).ms(part.tempo) * part.time_scale
			key := part_key(part)
			if d < shortest[key] {
				shortest[key] = d
			}
		}

		event.update_score(mut score) or {
			score.chord_mode = false
			return err
		}
	}
	score.chord_mode = false

	for mut part in score.current_parts {
		part.last_offset = part.current_offset
		part.current_offset += shortest[part_key(part)]
	}
}

// A Cram expression fits a variable number of events into a fixed duration,
// preserving the relative durations of the events.
pub struct Cram {
pub:
	source_context AldaSourceContext
	events         []ScoreUpdate
	duration       Duration
}

// The "inner duration" is the sum of the durations of the events, in the
// context of a copy of the part (because duration_ms can mutate the part).
fn inner_duration_ms(cram Cram, part &Part) f64 {
	mut part_copy := part.clone()
	mut total := 0.0
	for event in cram.events {
		total += event.duration_ms(mut part_copy)
	}
	return total
}

fn time_scale(cram Cram, part &Part) f64 {
	// The "outer duration" is the duration of the whole cram expression, e.g.
	// an eighth note in {c c c c c c c}8.
	outer := effective_duration(cram.duration, part).ms(part.tempo)
	inner := inner_duration_ms(cram, part)
	return (part.time_scale / inner) * outer
}

pub fn (cram Cram) update_score(mut score Score) ! {
	mut previous_durations := map[u64]Duration{}
	mut previous_time_scales := map[u64]f64{}
	for part in score.current_parts {
		previous_durations[part_key(part)] = part.duration
		previous_time_scales[part_key(part)] = part.time_scale
	}

	for mut part in score.current_parts {
		part.time_scale = time_scale(cram, part)
	}

	for event in cram.events {
		event.update_score(mut score)!
	}

	for mut part in score.current_parts {
		key := part_key(part)
		// A cram with a specified duration sets the new default duration.
		if cram.duration.is_specified() {
			part.duration = cram.duration
		} else if d := previous_durations[key] {
			part.duration = d
		}
		if ts := previous_time_scales[key] {
			part.time_scale = ts
		}
	}
}
