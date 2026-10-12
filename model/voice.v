module model

// Voices maps voice numbers to parts, remembering insertion order so that we
// know which voice was added last.
@[heap]
pub struct Voices {
pub mut:
	voices          map[int]&Part
	insertion_order []int
}

pub fn new_voices() &Voices {
	return &Voices{}
}

pub fn (mut v Voices) add_voice(voice_number int, voice &Part) {
	v.voices[voice_number] = voice
	v.insertion_order << voice_number
}

// new_voice creates and returns a new voice.
pub fn (mut part Part) new_voice(voice_number int) &Part {
	if part.voices.voices.len == 0 {
		if !isnil(part.voice_template) {
			panic('Part has no voices, but part.voice_template is set')
		}

		// The template captures the state of the part as of the start of each
		// voice.
		mut template := part.clone()
		template.voice_template = template
		part.voice_template = template
	}

	voice := part.voice_template.clone()
	mut voices := part.voices
	voices.add_voice(voice_number, voice)
	return voice
}

// get_voice returns an existing voice or creates a new one.
pub fn (mut part Part) get_voice(voice_number int) &Part {
	if existing := part.voices.voices[voice_number] {
		return existing
	}
	return part.new_voice(voice_number)
}

// A VoiceMarker indicates that the following events belong to one voice in a
// group of voices.
pub struct VoiceMarker {
pub:
	source_context AldaSourceContext
	voice_number   int
}

// update_score forks each current part into a voice, starting a voice group if
// needed.
pub fn (vm VoiceMarker) update_score(mut score Score) ! {
	for i, part in score.current_parts {
		mut origin := part.origin
		score.current_parts[i] = origin.get_voice(vm.voice_number)
	}
}

// A VoiceGroupEndMarker denotes the end of a voice group.
pub struct VoiceGroupEndMarker {
pub:
	source_context AldaSourceContext
}

// update_score makes the last voice to finish (offset-wise) "the" part going
// forward, replacing the origin part everywhere it's referenced.
pub fn (_ VoiceGroupEndMarker) update_score(mut score Score) ! {
	for i, part in score.current_parts {
		mut origin := part.origin
		if isnil(origin) || origin.voices.voices.len == 0 {
			continue
		}

		insertion_order := origin.voices.insertion_order
		mut last_to_finish := origin.get_voice(insertion_order.last())

		if origin.voices.voices.len > 1 {
			for voice_number in insertion_order[..insertion_order.len - 1] {
				mut voice := origin.get_voice(voice_number)
				if voice.current_offset > last_to_finish.current_offset {
					last_to_finish = voice
				}
			}
		}

		last_to_finish.voices = new_voices()
		last_to_finish.voice_template = unsafe { nil }
		last_to_finish.origin = last_to_finish

		score.current_parts[i] = last_to_finish

		for j, parts_part in score.parts {
			if same(parts_part, origin) {
				score.parts[j] = last_to_finish
			}
		}

		for _, mut parts in score.aliases {
			for j, alias_part in parts {
				if same(alias_part, origin) {
					parts[j] = last_to_finish
				}
			}
		}
	}
}
