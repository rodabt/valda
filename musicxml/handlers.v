module musicxml

import encoding.xml
import math
import model

// Element handlers. MusicXML elements fall into 3 categories: (1) supported
// (fully or partially); (2) not (yet) supported, which have to do with how the
// music sounds, for which we warn the user; (3) elements purely about
// appearance, which are skipped silently.

fn handle(element xml.XMLNode, mut imp Importer) {
	match element.name {
		'score-part' { score_part_handler(element, mut imp) }
		'part' { part_handler(element, mut imp) }
		'measure' { measure_handler(element, mut imp) }
		'barline' { barline_handler(element, mut imp) }
		'key' { key_handler(element, mut imp) }
		'dynamics' { dynamics_handler(element, mut imp) }
		'divisions' { divisions_handler(element, mut imp) }
		'transpose' { transpose_handler(element, mut imp) }
		'note' { note_handler(element, mut imp) }
		'forward' { forward_handler(element, mut imp) }
		'backup' { backup_handler(element, mut imp) }
		else { recurse_handler(element, mut imp) }
	}
}

// unsupported warns about category (2) elements, once per tag.
fn unsupported(tag string, element_name string, is_planned bool, mut imp Importer) {
	if tag in imp.unsupported {
		return
	}
	imp.unsupported.prepend(tag)
	if is_planned {
		warn('${element_name} with the <${tag}> tag are currently not supported for MusicXML import.
We plan to add support for importing ${element_name} in the future.')
	} else {
		warn('${element_name} with the <${tag}> tag are not supported for MusicXML import.')
	}
}

fn recurse_handler(element xml.XMLNode, mut imp Importer) {
	for child in child_elements(element) {
		handle(child, mut imp)
	}
}

fn score_part_handler(element xml.XMLNode, mut imp Importer) {
	id := attr(element, 'id', '')
	mut part := &Part{}
	imp.parts[id] = part

	midi_instruments := find_elements(element, 'midi-instrument')
	if midi_instruments.len == 0 {
		// Default to a piano.
		part.instruments = ['piano']
	} else if find_elements(element, 'midi-instrument/midi-unpitched').len > 0 {
		// Unpitched percussion
		part.instruments = ['midi-percussion']
		if name := find_element(element, 'part-name') {
			part.alias = percussion_part_name_to_alias(text(name))
		}
		for instrument in midi_instruments {
			unpitched := find_element(instrument, 'midi-unpitched') or { continue }
			part.unpitched[attr(instrument, 'id', '')] = text(unpitched).int() - 1
		}
	} else {
		// Pitched instruments, identified by midi-program.
		instruments_list := model.instruments_list()
		for instrument in midi_instruments {
			program := find_element(instrument, 'midi-program') or { continue }
			n := text(program).int()
			if n >= 1 && n <= 128 {
				part.instruments << instruments_list[n - 1]
			}
		}
		if part.instruments.len == 0 {
			part.instruments = ['piano']
		}
	}

	// If there's an existing part with the same instruments and alias, make
	// both unique by incorporating the IDs into the aliases.
	for k, mut v in imp.parts {
		if k != id && v.instruments == part.instruments && v.alias == part.alias {
			v.alias = add_id_to_alias(v.alias, k)
			part.alias = add_id_to_alias(part.alias, id)
		}
	}
}

fn add_id_to_alias(alias string, id string) string {
	return if alias == '' { id } else { alias + '_${id}' }
}

fn try_add_barline(update model.ScoreUpdate) ?model.ScoreUpdate {
	match update {
		model.Note {
			// Alda doesn't parse a barline after a slurred note into its duration.
			if !update.slurred {
				mut components := update.duration.components.clone()
				components << model.Barline{}
				return model.Note{
					...update
					duration: model.Duration{
						components: components
					}
				}
			}
		}
		model.Rest {
			mut components := update.duration.components.clone()
			components << model.Barline{}
			return model.Rest{
				...update
				duration: model.Duration{
					components: components
				}
			}
		}
		model.Chord {
			// Recurse on the last event.
			if update.events.len > 0 {
				if last := try_add_barline(update.events.last()) {
					mut events := update.events.clone()
					events[events.len - 1] = last
					return model.Chord{
						...update
						events: events
					}
				}
			}
		}
		else {}
	}
	return none
}

// add_barline adds a barline to represent a measure passing, the way Alda
// parses them (as part of the last note/rest's duration, to account for ties
// across measures).
fn add_barline(mut imp Importer) {
	last := imp.last() or {
		imp.append(model.Barline{})
		return
	}
	if with_barline := try_add_barline(last) {
		mut updates := imp.updates()
		updates[updates.len - 1] = with_barline
		imp.set_all(updates)
	} else {
		imp.append(model.Barline{})
	}
}

fn create_voices(element xml.XMLNode, mut part Part) {
	if element.name == 'voice' {
		part.voices[text(element).int()] = new_voice()
	}
	for child in child_elements(element) {
		create_voices(child, mut part)
	}
}

fn part_handler(element xml.XMLNode, mut imp Importer) {
	id := attr(element, 'id', '')
	mut part := imp.parts[id] or {
		warn_while_parsing(element.name, 'part with unknown id "${id}"')
		return
	}
	imp.current_part = part

	// Create all voices up front, so that they can be filled with rests and
	// barlines as we import.
	create_voices(element, mut part)
	if part.voices.len == 0 {
		part.voices[1] = new_voice()
	}
	part.current = part.voices[1] or { part.voices.values()[0] }

	children := child_elements(element)
	for i, child in children {
		handle(child, mut imp)
		// Between measures: pad each voice with rests (we can never back up to
		// before a measure) and add barlines.
		for _, voice in part.voices {
			part.current = voice
			pad_voice_to_present(child.name, mut imp)
			if i < children.len - 1 {
				add_barline(mut imp)
			}
		}
	}
}

// pad_voice_to_present fills the current voice with rests to catch up with
// the part's beat counter.
fn pad_voice_to_present(tag string, mut imp Importer) {
	beat_difference := imp.part().beats - imp.voice().beats

	if beat_difference < 0 {
		warn_while_parsing(tag, 'Voice is found to be behind in beats so output will not be entirely accurate.')
	} else if beat_difference > 0 {
		// Pad the voice to catch up, without moving the part-level beats.
		imp.append(model.Rest{
			duration: idiomatic_duration(4 / beat_difference, 0)
		})
		mut voice := imp.voice()
		voice.beats += beat_difference
	}
}

fn measure_handler(element xml.XMLNode, mut imp Importer) {
	for child in child_elements(element) {
		// Voice switching is handled at the measure level.
		if voice := find_element(child, 'voice') {
			mut part := imp.part()
			if v := part.voices[text(voice).int()] {
				part.current = v
			}
			pad_voice_to_present(child.name, mut imp)
		}
		handle(child, mut imp)
	}
}

fn count_endings(mut imp Importer) int {
	repeat, _ := imp.find_last(is_repeat)
	r := repeat or { return 0 }
	if r is model.Repeat {
		return events_of(r.event).filter(it is model.OnRepetitions).len
	}
	return 0
}

fn set_repeat_times(mut imp Importer, times int) {
	_, ni := imp.find_last(is_repeat)
	imp.modify_at(ni, fn [times] (update model.ScoreUpdate) model.ScoreUpdate {
		if update is model.Repeat {
			return model.Repeat{
				...update
				times: times
			}
		}
		return update
	})
}

fn maintain_repeat_octave_integrity(mut imp Importer) {
	mut voice := imp.voice()
	for voice.octave > voice.section_start_octave {
		imp.append(model.AttributeUpdate{
			part_update: model.OctaveDown{}
		})
		voice.octave--
	}
	for voice.octave < voice.section_start_octave {
		imp.append(model.AttributeUpdate{
			part_update: model.OctaveUp{}
		})
		voice.octave++
	}
}

fn set_ending_repetitions(mut imp Importer) {
	ending_number := count_endings(mut imp)
	ranges := [model.RepetitionRange{
		first: ending_number
		last:  ending_number
	}]
	_, ni := imp.find_last(filter_nested_importable_update)
	imp.modify_at(ni, fn [ranges] (update model.ScoreUpdate) model.ScoreUpdate {
		if update is model.OnRepetitions {
			return model.OnRepetitions{
				...update
				repetitions: ranges
			}
		}
		return update
	})
}

fn barline_handler(element xml.XMLNode, mut imp Importer) {
	ending := find_element(element, 'ending')
	mut ending_type := ''
	if e := ending {
		ending_type = attr(e, 'type', '')
		if ending_type == 'discontinue' {
			// Treated the same as stopping
			ending_type = 'stop'
		}
	}

	repeat := find_element(element, 'repeat')
	mut repeat_direction := ''
	if r := repeat {
		repeat_direction = attr(r, 'direction', '')
	}

	import_to, _ := imp.find_last(filter_nested_importable_update)
	is_repeat_ongoing := if u := import_to { u is model.Repeat } else { false }

	has_ending := ending != none
	has_repeat := repeat != none

	if !has_ending && !has_repeat {
		return
	}

	// Starting repeats and endings
	if !has_ending && repeat_direction == 'forward' {
		// (1) Repeat starting (no ending)
		start_repeat(mut imp)
	} else if ending_type == 'start' && repeat_direction == 'forward' {
		// (2) Repeat and first ending starting
		start_repeat(mut imp)
		start_ending(mut imp)
	} else if ending_type == 'start' && !is_repeat_ongoing {
		// (3) First ending starting, with no repeat yet: build the repeat.
		imp.set_all([
			model.ScoreUpdate(model.Repeat{
				event: model.EventSequence{
					events: imp.flat_updates()
				}
			}),
		])
		start_ending(mut imp)
	} else if ending_type == 'start' && is_repeat_ongoing {
		// (4) Another ending starting
		imp.append(model.OnRepetitions{
			event: model.EventSequence{}
		})
	}

	// Concluding repeats and endings
	if !has_ending && repeat_direction == 'backward' {
		// (1) A normal repeat with no endings
		maintain_repeat_octave_integrity(mut imp)
		r := repeat or { return }
		times := attr(r, 'times', '2').int()

		if !is_repeat_ongoing {
			// Create the repeat with all the existing score updates.
			imp.set_all([
				model.ScoreUpdate(model.Repeat{
					event: model.EventSequence{
						events: imp.flat_updates()
					}
				}),
			])
		}
		set_repeat_times(mut imp, times)
	} else if ending_type == 'stop' && !has_repeat {
		// (2) Only an ending concluding: the last ending in a repeated section.
		set_ending_repetitions(mut imp)
		set_repeat_times(mut imp, count_endings(mut imp))
	} else if ending_type == 'stop' && repeat_direction == 'backward' {
		// (3) Ending and repeat concluding: not the last ending.
		maintain_repeat_octave_integrity(mut imp)
		set_ending_repetitions(mut imp)
		// Going to the next ending skips the previous endings.
		mut voice := imp.voice()
		voice.octave = voice.ending_start_octave
	}
}

fn start_repeat(mut imp Importer) {
	mut voice := imp.voice()
	voice.section_start_octave = voice.octave
	imp.append(model.Repeat{
		event: model.EventSequence{}
	})
}

fn start_ending(mut imp Importer) {
	mut voice := imp.voice()
	voice.ending_start_octave = voice.octave
	imp.append(model.OnRepetitions{
		event: model.EventSequence{}
	})
}

fn backup_handler(element xml.XMLNode, mut imp Importer) {
	// Move the part-level beat counter back. We assume we can't back up to
	// before an existing note in a voice.
	d, _ := translate_duration(element, mut imp)
	mut part := imp.part()
	part.beats -= get_beats(model.Rest{
		duration: d
	})
}

fn forward_handler(element xml.XMLNode, mut imp Importer) {
	d, _ := translate_duration(element, mut imp)
	mut part := imp.part()
	part.beats += get_beats(model.Rest{
		duration: d
	})
}

fn key_handler(element xml.XMLNode, mut imp Importer) {
	if _ := find_element(element, 'key-step') {
		unsupported(element.name, 'non-traditional key signatures', false, mut imp)
		return
	}
	if _ := find_element(element, 'key-alter') {
		unsupported(element.name, 'non-traditional key signatures', false, mut imp)
		return
	}
	if _ := find_element(element, 'key-accidental') {
		unsupported(element.name, 'non-traditional key signatures', false, mut imp)
		return
	}

	fifths := find_element(element, 'fifths') or { return }
	imp.append_part_attrs(model.AttributeUpdate{
		part_update: model.KeySignatureSet{
			key_signature: model.key_signature_from_circle_of_fifths(text(fifths).int())
		}
	})
}

fn dynamics_handler(element xml.XMLNode, mut imp Importer) {
	for marking in child_elements(element) {
		if marking.name in model.dynamic_volumes {
			imp.append(model.AttributeUpdate{
				part_update: model.DynamicMarking{
					marking: marking.name
				}
			})
		} else {
			unsupported(marking.name, 'dynamics', false, mut imp)
		}
	}
}

fn divisions_handler(element xml.XMLNode, mut imp Importer) {
	mut part := imp.part()
	part.divisions = text(element).int()
}

fn transpose_handler(element xml.XMLNode, mut imp Importer) {
	chromatic := find_element(element, 'chromatic') or { return }
	imp.append_part_attrs(model.AttributeUpdate{
		part_update: model.TranspositionSet{
			semitones: text(chromatic).int()
		}
	})
}

// translate_duration translates an element's duration to an Alda duration,
// using the part's divisions.
fn translate_duration(element xml.XMLNode, mut imp Importer) (model.Duration, f64) {
	dots := find_elements(element, 'dot').len

	// Remove the dots' contribution: n dots multiply the duration by the
	// geometric series sum (1 - (1/2)^(n+1)) / (1/2).
	mut duration := if d := find_element(element, 'duration') { text(d).f64() } else { 0.0 }
	if dots > 0 {
		duration = duration / ((1 - math.pow(0.5, f64(dots + 1))) / 0.5)
	}

	alda_duration := 4 * f64(imp.part().divisions) / duration
	return idiomatic_duration(alda_duration, dots), alda_duration
}

struct TranslatedNote {
	updates     []model.ScoreUpdate
	octave      int
	duration    f64
	slur_change int
}

// translate_note translates a MusicXML note into score updates, without
// handling chords or ties, and without modifying importer state.
fn translate_note(element xml.XMLNode, mut imp Importer) TranslatedNote {
	note_type := find_element(element, 'type')
	type_attr := if t := note_type { attr(t, 'type', 'full') } else { 'full' }

	if _ := find_element(element, 'cue') {
		// Cue notes don't change the sound directly.
		unsupported('cue', 'cue notes', true, mut imp)
		return TranslatedNote{}
	} else if type_attr == 'cue' {
		unsupported('cue', 'cue notes', true, mut imp)
		return TranslatedNote{}
	}
	if _ := find_element(element, 'grace') {
		unsupported('grace', 'grace notes', false, mut imp)
		return TranslatedNote{}
	} else if type_attr == 'grace' {
		unsupported('grace', 'grace notes', false, mut imp)
		return TranslatedNote{}
	}

	d, duration_value := translate_duration(element, mut imp)

	mut slur_change := 0
	for slur in find_elements(element, 'notations/slur') {
		match attr(slur, 'type', 'none') {
			'start' { slur_change++ }
			'stop' { slur_change-- }
			else {}
		}
	}

	slurred := imp.voice().slurs + slur_change > 0
	voice_octave := imp.voice().octave

	if pitch := find_element(element, 'pitch') {
		step := find_element(pitch, 'step') or { return TranslatedNote{} }
		step_text := text(step).to_lower()
		letter := model.new_note_letter(if step_text.len > 0 { rune(step_text[0]) } else { `c` }) or {
			model.NoteLetter.c
		}

		mut accidentals := []model.Accidental{}
		mut is_natural := false
		if acc := find_element(element, 'accidental') {
			is_natural = text(acc) == 'natural'
		}
		if is_natural {
			accidentals = [model.Accidental.natural]
		} else if alter := find_element(pitch, 'alter') {
			alter_amount := int(text(alter).f64())
			accidental := if alter_amount > 0 {
				model.Accidental.sharp
			} else {
				model.Accidental.flat
			}
			for _ in 0 .. math.abs(alter_amount) {
				accidentals << accidental
			}
		}

		octave_val := if o := find_element(pitch, 'octave') { text(o).int() } else { voice_octave }
		mut updates := []model.ScoreUpdate{}
		octave_difference := octave_val - voice_octave
		if octave_difference != 0 {
			if imp.voice().score_updates().len == 0 {
				// The first note gets an octave set.
				updates << model.AttributeUpdate{
					part_update: model.OctaveSet{
						octave_number: octave_val
					}
				}
			} else {
				pu := if octave_difference > 0 {
					model.PartUpdate(model.OctaveUp{})
				} else {
					model.PartUpdate(model.OctaveDown{})
				}
				for _ in 0 .. math.abs(octave_difference) {
					updates << model.AttributeUpdate{
						part_update: pu
					}
				}
			}
		}

		updates << model.Note{
			pitch:    model.LetterAndAccidentals{
				note_letter:     letter
				accidentals:     accidentals
				has_accidentals: accidentals.len > 0
			}
			duration: d
			slurred:  slurred
		}

		return TranslatedNote{updates, octave_val, duration_value, slur_change}
	}

	if _ := find_element(element, 'rest') {
		return TranslatedNote{[model.ScoreUpdate(model.Rest{
			duration: d
		})], voice_octave, duration_value, 0}
	}

	// Unpitched note
	instrument_id := if i := find_element(element, 'instrument') { attr(i, 'id', '') } else { '' }
	if number := imp.part().unpitched[instrument_id] {
		// The octave isn't tracked here; MIDI note numbers include it.
		return TranslatedNote{[
			model.ScoreUpdate(model.Note{
				pitch:    model.MidiNoteNumber{
					midi_note: number
				}
				duration: d
				slurred:  slurred
			}),
		], voice_octave, duration_value, slur_change}
	}

	warn_while_parsing(element.name, 'Could not find instrument for unpitched note. Note will be replaced with a rest.')
	return TranslatedNote{[model.ScoreUpdate(model.Rest{
		duration: d
	})], voice_octave, duration_value, slur_change}
}

fn pitches_match(a model.PitchIdentifier, b model.PitchIdentifier) bool {
	if a is model.MidiNoteNumber && b is model.MidiNoteNumber {
		return a.midi_note == b.midi_note
	}
	return false
}

fn note_handler(element xml.XMLNode, mut imp Importer) {
	translated := translate_note(element, mut imp)
	note_updates := translated.updates
	if note_updates.len == 0 {
		return
	}

	is_chord := find_element(element, 'chord') != none

	mut is_tie_stop := false
	for tie in find_elements(element, 'tie') {
		if attr(tie, 'type', '') == 'stop' {
			is_tie_stop = true
		}
	}
	// Rests can't be tied.
	if note_updates.last() !is model.Note {
		is_tie_stop = false
	}

	if is_tie_stop {
		// A note with a tie stop is tied to the previous note with the same
		// pitch, so find that note first.
		note := note_updates.last() as model.Note
		new_octave := translated.octave
		note_pitch := note.pitch

		filter := fn [note_pitch, new_octave] (update model.ScoreUpdate, octave int) bool {
			if update is model.Note {
				pitch := update.pitch
				match pitch {
					model.LetterAndAccidentals {
						if note_pitch is model.LetterAndAccidentals {
							return octave == new_octave
								&& pitch.note_letter == note_pitch.note_letter
						}
						return false
					}
					model.MidiNoteNumber {
						return pitches_match(pitch, note_pitch)
					}
				}
			}
			return false
		}

		tie_start, tie_start_ni, _ := find_last_with_octave(imp.voice().updates, filter,
			imp.voice().octave)

		if !imp.valid(tie_start_ni) {
			warn_while_parsing(element.name, 'cannot find start of tie')
			return
		}

		// A note can be tied to a previous note even with a gap between them; in
		// that case the second note isn't logical, so we ignore it. Notes in a
		// MusicXML chord all have the same duration, so we compare the index of
		// the last update with a duration with the tie start's index.
		_, last_duration_ni := imp.find_last(is_duration_update)
		mut index_diff := last_diff(last_duration_ni, tie_start_ni)

		mut is_adjacent_tie := false
		if is_chord {
			// In a chord, one element (the start of the chord) is allowed.
			if index_diff <= 0 {
				is_adjacent_tie = true
			} else {
				_, last_last_duration_ni := imp.find_last_from(is_duration_update, last_duration_ni.last())
				if !imp.valid(last_duration_ni) {
					is_adjacent_tie = true
				} else if last_last_duration_ni.indices.len > 0 {
					index_diff = last_diff(last_last_duration_ni, tie_start_ni)
					is_adjacent_tie = index_diff <= 0
				}
			}
		} else {
			is_adjacent_tie = index_diff <= 0
		}

		if is_adjacent_tie {
			start := tie_start or { return }
			if start is model.Note {
				mut components := start.duration.components.clone()
				components << note.duration.components
				imp.set_at(tie_start_ni, model.Note{
					...start
					duration: model.Duration{
						components: components
					}
				})
			}
		} else {
			warn_while_parsing(element.name, 'Found nonadjacent tied note.')
		}
		return
	}

	if is_chord {
		last_duration_element, last_duration_ni := imp.find_last(is_duration_update)

		if !imp.valid(last_duration_ni) {
			warn_while_parsing(element.name, 'Note found in chord with no starting note. The note will be ignored.')
			return
		}

		last := last_duration_element or { return }
		match last {
			model.Chord {
				// Add the note updates to the existing chord.
				mut events := last.events.clone()
				events << note_updates
				update_importer_state(mut imp, translated)
				imp.set_at(last_duration_ni, model.Chord{
					...last
					events: events
				})
			}
			model.Note, model.Rest {
				// Create a chord from the previous updates and the new note.
				current := imp.updates()
				index := last_duration_ni.last()
				mut events := current[index..].clone()
				events << note_updates
				update_importer_state(mut imp, translated)
				mut new_updates := imp.updates()[..index].clone()
				new_updates << model.Chord{
					events: events
				}
				imp.set_all(new_updates)
			}
			else {}
		}
		return
	}

	update_importer_state(mut imp, translated)
	imp.append(...note_updates)
}

fn update_importer_state(mut imp Importer, translated TranslatedNote) {
	mut voice := imp.voice()
	voice.octave = translated.octave
	voice.slurs += translated.slur_change
}
