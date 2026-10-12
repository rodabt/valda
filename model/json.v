module model

import x.json2

// JSON representations, mirroring the shapes produced by Alda's Go client
// (`alda parse -o events` / `-o data`).

pub fn obj(pairs ...json2.Any) json2.Any {
	mut m := map[string]json2.Any{}
	for i := 0; i + 1 < pairs.len; i += 2 {
		m[(pairs[i] as string)] = pairs[i + 1]
	}
	return json2.Any(m)
}

pub fn arr(items []json2.Any) json2.Any {
	return json2.Any(items)
}

fn f(x f64) json2.Any {
	return json2.Any(x)
}

fn n(x int) json2.Any {
	return json2.Any(x)
}

fn s(x string) json2.Any {
	return json2.Any(x)
}

pub fn (d DurationComponent) json() json2.Any {
	return match d {
		Barline { obj(s('type'), s('barline')) }
		Duration { d.json() }
		NoteLength { obj(s('denominator'), f(d.denominator), s('dots'), n(d.dots)) }
		NoteLengthBeats { obj(s('beats'), f(d.quantity)) }
		NoteLengthMs { obj(s('ms'), f(d.quantity)) }
		NoteLengthSeconds { obj(s('s'), f(d.quantity)) }
	}
}

pub fn (d Duration) json() json2.Any {
	return obj(s('components'), arr(d.components.map(it.json())))
}

pub fn (ks KeySignature) json() json2.Any {
	mut m := map[string]json2.Any{}
	for letter in all_letters {
		accidentals := ks.entries[int(letter)] or { continue }
		m[letter.str()] = arr(accidentals.map(json2.Any(it.str())))
	}
	return json2.Any(m)
}

pub fn (p PitchIdentifier) json() json2.Any {
	return match p {
		LetterAndAccidentals {
			obj(s('letter'), s(p.note_letter.str()), s('accidentals'), arr(p.accidentals.map(json2.Any(it.str()))))
		}
		MidiNoteNumber {
			obj(s('midi-note'), n(p.midi_note))
		}
	}
}

pub fn (pu PartUpdate) json() json2.Any {
	return match pu {
		TempoSet {
			obj(s('attribute'), s('tempo'), s('value'), f(pu.tempo))
		}
		MetricModulation {
			obj(s('attribute'), s('tempo'), s('value'), obj(s('ratio'), f(pu.ratio)))
		}
		OctaveSet {
			obj(s('attribute'), s('octave'), s('value'), n(pu.octave_number))
		}
		OctaveUp {
			obj(s('attribute'), s('octave'), s('value'), s('up'))
		}
		OctaveDown {
			obj(s('attribute'), s('octave'), s('value'), s('down'))
		}
		VolumeSet {
			obj(s('attribute'), s('volume'), s('value'), f(pu.volume))
		}
		TrackVolumeSet {
			obj(s('attribute'), s('track-volume'), s('value'), f(pu.track_volume))
		}
		DynamicMarking {
			obj(s('attribute'), s('dynamic-marking'), s('value'), s(pu.marking))
		}
		PanningSet {
			obj(s('attribute'), s('panning'), s('value'), f(pu.panning))
		}
		QuantizationSet {
			obj(s('attribute'), s('quantization'), s('value'), f(pu.quantization))
		}
		DurationSet {
			obj(s('attribute'), s('duration'), s('components'), arr(pu.duration.components.map(it.json())))
		}
		KeySignatureSet {
			obj(s('attribute'), s('key-signature'), s('value'), pu.key_signature.json())
		}
		TranspositionSet {
			obj(s('attribute'), s('transposition'), s('value'), n(pu.semitones))
		}
		ReferencePitchSet {
			obj(s('attribute'), s('reference-pitch'), s('value'), f(pu.frequency))
		}
		MidiChannelSet {
			obj(s('attribute'), s('midi-channel'), s('value'), n(pu.channel_number))
		}
	}
}

fn with_type(o json2.Any, typ string) json2.Any {
	mut m := (o as map[string]json2.Any).clone()
	m['type'] = s(typ)
	return json2.Any(m)
}

fn events_json(events []ScoreUpdate) json2.Any {
	return arr(events.map(it.json()))
}

pub fn (u ScoreUpdate) json() json2.Any {
	match u {
		AtMarker {
			return obj(s('type'), s('at-marker'), s('value'), obj(s('name'), s(u.name)))
		}
		AttributeUpdate {
			return with_type(u.part_update.json(), 'attribute-update')
		}
		Barline {
			return obj(s('type'), s('barline'))
		}
		Chord {
			return obj(s('type'), s('chord'), s('value'), obj(s('events'), events_json(u.events)))
		}
		Cram {
			mut value := map[string]json2.Any{}
			value['events'] = events_json(u.events)
			if u.duration.is_specified() {
				value['duration'] = u.duration.json()
			}
			return obj(s('type'), s('cram'), s('value'), json2.Any(value))
		}
		EventSequence {
			return obj(s('type'), s('event-sequence'), s('value'), obj(s('events'), events_json(u.events)))
		}
		GlobalAttributeUpdate {
			return with_type(u.part_update.json(), 'global-attribute-update')
		}
		LispList {
			return LispForm(u).json()
		}
		LispNil {
			return obj(s('type'), s('nil'))
		}
		Marker {
			return obj(s('type'), s('marker'), s('value'), obj(s('name'), s(u.name)))
		}
		Note {
			mut value := map[string]json2.Any{}
			value['pitch'] = u.pitch.json()
			if u.duration.is_specified() {
				value['duration'] = u.duration.json()
			}
			if u.slurred {
				value['slurred?'] = json2.Any(true)
			}
			return obj(s('type'), s('note'), s('value'), json2.Any(value))
		}
		OnRepetitions {
			reps := u.repetitions.map(obj(s('first'), n(it.first), s('last'), n(it.last)))
			return obj(s('type'), s('on-repetitions'), s('value'), obj(s('repetitions'),
				arr(reps), s('event'), u.event.json()))
		}
		PartDeclaration {
			mut value := map[string]json2.Any{}
			value['names'] = arr(u.names.map(json2.Any(it)))
			if u.alias != '' {
				value['alias'] = s(u.alias)
			}
			return obj(s('type'), s('part-declaration'), s('value'), json2.Any(value))
		}
		Repeat {
			return obj(s('type'), s('repeat'), s('value'), obj(s('event'), u.event.json(),
				s('times'), n(u.times)))
		}
		Rest {
			mut value := map[string]json2.Any{}
			if u.duration.is_specified() {
				value['duration'] = u.duration.json()
			}
			return obj(s('type'), s('rest'), s('value'), json2.Any(value))
		}
		VariableDefinition {
			return obj(s('type'), s('variable-definition'), s('value'), obj(s('events'),
				events_json(u.events)))
		}
		VariableReference {
			return obj(s('type'), s('variable-reference'), s('value'), obj(s('name'),
				s(u.variable_name)))
		}
		VoiceGroupEndMarker {
			return obj(s('type'), s('voice-group-end-marker'))
		}
		VoiceMarker {
			return obj(s('type'), s('voice-marker'), s('value'), obj(s('number'), n(u.voice_number)))
		}
	}
}

pub fn (form LispForm) json() json2.Any {
	return match form {
		LispDuration { obj(s('type'), s('duration'), s('value'), form.component.json()) }
		LispFunction { obj(s('type'), s('function'), s('value'), s('<fn ${form.name}>')) }
		LispList { obj(s('type'), s('list'), s('value'), arr(form.elements.map(it.json()))) }
		LispNil { obj(s('type'), s('nil')) }
		LispNumber { obj(s('type'), s('number'), s('value'), f(form.value)) }
		LispPitch { obj(s('type'), s('pitch'), s('value'), form.pitch.json()) }
		LispQuotedForm { obj(s('type'), s('quoted-form'), s('value'), form.form.json()) }
		LispScoreUpdate { obj(s('type'), s('score-update'), s('value'), form.score_update.json()) }
		LispSpecialFormQuote { obj(s('type'), s('special-form'), s('value'), s('quote')) }
		LispString { obj(s('type'), s('string'), s('value'), s(form.value)) }
		LispSymbol { obj(s('type'), s('symbol'), s('value'), s(form.name)) }
	}
}

pub fn (e NoteEvent) json() json2.Any {
	return obj(s('part'), s(e.part.id), s('midi-channel'), n(e.midi_channel), s('midi-note'),
		n(e.midi_note), s('offset'), f(e.offset), s('duration'), f(e.duration), s('audible-duration'),
		f(e.audible_duration), s('volume'), f(e.volume), s('track-volume'), f(e.track_volume),
		s('panning'), f(e.panning))
}

fn offset_key(offset f64) string {
	return '${offset:.6f}'
}

pub fn (part &Part) json() json2.Any {
	mut tempo_values := map[string]json2.Any{}
	for offset, tempo in part.tempo_values {
		tempo_values[offset_key(offset)] = f(tempo)
	}

	return obj(s('id'), s(part.id), s('name'), s(part.name), s('stock-instrument'), s(part.stock_instrument.name),
		s('tempo-role'), s(part.tempo_role.str()), s('tempo'), f(part.tempo), s('key-signature'),
		part.key_signature.json(), s('transposition'), n(part.transposition), s('reference-pitch'),
		f(part.reference_pitch), s('current-offset'), f(part.current_offset), s('last-offset'),
		f(part.last_offset), s('octave'), n(part.octave), s('volume'), f(part.volume),
		s('track-volume'), f(part.track_volume), s('panning'), f(part.panning), s('midi-channel'),
		n(part.midi_channel), s('quantization'), f(part.quantization), s('duration'),
		part.duration.json(), s('time-scale'), f(part.time_scale), s('tempo-values'),
		json2.Any(tempo_values))
}

pub fn (ga &GlobalAttributes) json() json2.Any {
	mut m := map[string]json2.Any{}
	for offset in ga.offsets {
		m[offset_key(offset)] = arr(ga.itinerary[offset].map(it.json()))
	}
	return json2.Any(m)
}

pub fn (score &Score) json() json2.Any {
	mut parts := map[string]json2.Any{}
	for part in score.parts {
		parts[part.id] = part.json()
	}

	mut aliases := map[string]json2.Any{}
	for alias, alias_parts in score.aliases {
		aliases[alias] = arr(alias_parts.map(json2.Any(it.id)))
	}

	mut markers := map[string]json2.Any{}
	for name, offset in score.markers {
		markers[name] = f(offset)
	}

	mut variables := map[string]json2.Any{}
	for name, events in score.variables {
		variables[name] = events_json(events)
	}

	return obj(s('parts'), json2.Any(parts), s('current-parts'), arr(score.current_parts.map(json2.Any(it.id))),
		s('aliases'), json2.Any(aliases), s('events'), arr(score.events.map(it.json())),
		s('global-attributes'), score.global_attributes.json(), s('markers'), json2.Any(markers),
		s('variables'), json2.Any(variables))
}
