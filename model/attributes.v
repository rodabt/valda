module model

// PartUpdate is something that updates an attribute of a part.
pub type PartUpdate = DurationSet
	| DynamicMarking
	| KeySignatureSet
	| MetricModulation
	| MidiChannelSet
	| OctaveDown
	| OctaveSet
	| OctaveUp
	| PanningSet
	| QuantizationSet
	| ReferencePitchSet
	| TempoSet
	| TrackVolumeSet
	| TranspositionSet
	| VolumeSet

pub struct TempoSet {
pub:
	tempo f64
}

// MetricModulation sets the tempo as a ratio of new tempo : old tempo.
pub struct MetricModulation {
pub:
	ratio f64
}

pub struct OctaveSet {
pub:
	octave_number int
}

pub struct OctaveUp {}

pub struct OctaveDown {}

pub struct VolumeSet {
pub:
	volume f64
}

pub struct TrackVolumeSet {
pub:
	track_volume f64
}

pub struct DynamicMarking {
pub:
	marking string
}

pub struct PanningSet {
pub:
	panning f64
}

pub struct QuantizationSet {
pub:
	quantization f64
}

pub struct DurationSet {
pub:
	duration Duration
}

pub struct KeySignatureSet {
pub:
	key_signature KeySignature
}

pub struct TranspositionSet {
pub:
	semitones int
}

// ReferencePitchSet sets the frequency of A4.
pub struct ReferencePitchSet {
pub:
	frequency f64
}

// MidiChannelSet explicitly sets the MIDI channel to use for a part. By
// default, a MIDI channel is assigned automatically.
pub struct MidiChannelSet {
pub:
	channel_number int
}

// Dynamic volumes follow a uniform distribution from 0 to 1, covering the full
// range of MusicXML dynamics. They map to MIDI velocity [0, 127].
pub const dynamic_volumes = {
	'pppppp': 0.00787 // 1
	'ppppp':  0.08419 // 11
	'pppp':   0.16051 // 20
	'ppp':    0.23683 // 30
	'pp':     0.31314 // 40
	'p':      0.38946 // 49
	'mp':     0.46578 // 59
	'mf':     0.54210 // 69
	'f':      0.61841 // 79
	'ff':     0.69473 // 88
	'fff':    0.77105 // 98
	'ffff':   0.84737 // 108
	'fffff':  0.92368 // 117
	'ffffff': 1.00000 // 127
}

pub fn (pu PartUpdate) update_part(mut part Part, global_update bool) ! {
	match pu {
		TempoSet {
			part.tempo = pu.tempo
			// Global updates are recorded separately; recording them here would put
			// them at the part's offset rather than the global update's offset.
			if !global_update {
				part.record_tempo_value()
			}
		}
		MetricModulation {
			part.tempo *= pu.ratio
			if !global_update {
				part.record_tempo_value()
			}
		}
		OctaveSet {
			part.octave = pu.octave_number
		}
		OctaveUp {
			part.octave++
		}
		OctaveDown {
			part.octave--
		}
		VolumeSet {
			part.volume = pu.volume
		}
		TrackVolumeSet {
			part.track_volume = pu.track_volume
		}
		DynamicMarking {
			part.volume = dynamic_volumes[pu.marking]
		}
		PanningSet {
			part.panning = pu.panning
		}
		QuantizationSet {
			part.quantization = pu.quantization
		}
		DurationSet {
			part.duration = pu.duration
		}
		KeySignatureSet {
			part.key_signature = pu.key_signature
		}
		TranspositionSet {
			part.transposition = pu.semitones
		}
		ReferencePitchSet {
			part.reference_pitch = pu.frequency
		}
		MidiChannelSet {
			if pu.channel_number == 9 && !part.stock_instrument.is_percussion {
				return error('Can\'t use MIDI channel 9 for part "${part.name}"; channel 9 can only be used for
percussion.')
			}
			part.midi_channel = pu.channel_number
			part.has_explicit_midi_channel = true
		}
	}
}

// AttributeUpdate updates the value of an attribute for all current parts.
pub struct AttributeUpdate {
pub:
	source_context AldaSourceContext
	part_update    PartUpdate
}

pub fn (au AttributeUpdate) update_score(mut score Score) ! {
	for mut part in score.current_parts {
		au.part_update.update_part(mut part, false)!
		// Record that this local attribute was updated, so that it takes
		// precedence over a global attribute change at the exact same time.
		part.local_attribute_override = au.part_update
	}
}

// GlobalAttributes are attribute updates to be applied at specific points of
// time in a score, e.g. a tempo change at 5000ms for all parts.
pub struct GlobalAttributes {
pub mut:
	itinerary map[f64][]PartUpdate
	offsets   []f64
}

// record adds an attribute change at a particular offset to the itinerary.
pub fn (mut ga GlobalAttributes) record(offset f64, update PartUpdate) {
	if offset in ga.itinerary {
		ga.itinerary[offset] << update
		return
	}
	ga.itinerary[offset] = [update]
	ga.offsets << offset
	ga.offsets.sort()
}

// in_window returns the global attribute updates in (start_offset, end_offset].
pub fn (ga &GlobalAttributes) in_window(start_offset f64, end_offset f64) []PartUpdate {
	mut updates := []PartUpdate{}
	for offset in ga.offsets {
		if offset > end_offset {
			return updates
		}
		if offset > start_offset {
			updates << ga.itinerary[offset]
		}
	}
	return updates
}

// apply_global_attributes applies the global attribute updates registered
// between each current part's last_offset and current_offset.
pub fn (mut score Score) apply_global_attributes() ! {
	for mut part in score.current_parts {
		for update in score.global_attributes.in_window(part.last_offset, part.current_offset) {
			override_type := if o := part.local_attribute_override { o.type_name() } else { '' }
			if override_type != update.type_name() {
				update.update_part(mut part, true)!
			}
		}
		part.local_attribute_override = none
	}
}

// GlobalAttributeUpdate updates the value of an attribute for all parts.
pub struct GlobalAttributeUpdate {
pub:
	source_context AldaSourceContext
	part_update    PartUpdate
}

// update_score records that at this point in time, an attribute update should
// be applied for all parts.
pub fn (gau GlobalAttributeUpdate) update_score(mut score Score) ! {
	mut offset := 0.0
	if score.current_parts.len > 0 {
		offset = score.current_parts[0].current_offset
		for part in score.current_parts[1..] {
			if part.current_offset != offset {
				return error("can't set global attribute; there are multiple current parts with different offsets")
			}
		}
	}

	score.global_attributes.record(offset, gau.part_update)
}
