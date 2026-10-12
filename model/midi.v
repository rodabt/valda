module model

// MIDI channel assignment. score.midi_channel_usage records which parts use
// each of the 16 channels. Channel 9 is reserved for percussion.

fn (s &Score) channel_is_unused(channel int) bool {
	return s.midi_channel_usage[channel].len == 0
}

fn (s &Score) part_has_exclusive_access(part &Part, channel int) bool {
	usage := s.midi_channel_usage[channel]
	return usage.len == 1 && same(usage[0], part.origin)
}

fn (s &Score) simple_check(part &Part) ?int {
	for channel in 0 .. 16 {
		if channel == 9 {
			continue
		}
		if s.midi_channel_usage[channel].len == 0 || s.part_has_exclusive_access(part, channel) {
			return channel
		}
	}
	return none
}

fn overlaps(start1 f64, duration1 f64, start2 f64, duration2 f64) bool {
	return start2 < start1 + duration1 && start2 + duration2 > start1
}

fn (s &Score) complex_check(part &Part, note_duration_ms f64) ?int {
	mut unavailable := map[int]bool{}

	// Record channels that have notes belonging to other parts that overlap
	// with the proposed note.
	for note in s.events {
		if same(note.part.origin, part.origin) || note.midi_channel in unavailable {
			continue
		}
		if overlaps(note.offset, note.audible_duration, part.current_offset, note_duration_ms) {
			unavailable[note.midi_channel] = true
		}
	}

	// Prefer the channel already assigned, if it's still available.
	if part.midi_channel != -1 && part.midi_channel !in unavailable {
		return part.midi_channel
	}

	for channel in 0 .. 16 {
		if channel != 9 && channel !in unavailable {
			return channel
		}
	}

	return none
}

fn (s &Score) available_midi_channel(part &Part, note_duration_ms f64) !int {
	if channel := s.simple_check(part) {
		return channel
	}
	if channel := s.complex_check(part, note_duration_ms) {
		return channel
	}
	return error('No MIDI channel available for part "${part.name}" at offset ${part.current_offset:.6f}.

This means that your score has more than 16 instruments, and we tried to map
the instruments\' notes to the 16 MIDI channels by having multiple instruments
share a channel as needed, but it wasn\'t logistically possible.')
}

fn (s &Score) determine_midi_channel(part &Part, note_duration_ms f64) !int {
	if part.stock_instrument.is_percussion {
		return 9
	}

	if part.has_explicit_midi_channel {
		if s.channel_is_unused(part.midi_channel)
			|| s.part_has_exclusive_access(part, part.midi_channel) {
			return part.midi_channel
		}

		channel := s.complex_check(part, note_duration_ms) or { -1 }
		if channel != part.midi_channel {
			return error('The specified MIDI channel (${part.midi_channel}) for part "${part.name}" is not available at offset ${part.current_offset:.6f}.

This means that another part in the score is already using that channel at that
point in the score.

To address this, use the midi-channel attribute to assign a different MIDI
channel to each part in the score.')
		}
		return part.midi_channel
	}

	if part.midi_channel != -1 && s.part_has_exclusive_access(part, part.midi_channel) {
		return part.midi_channel
	}

	return s.available_midi_channel(part, note_duration_ms)
}

fn (mut s Score) assign_midi_channel(part &Part, note_duration_ms f64) !int {
	channel := s.determine_midi_channel(part, note_duration_ms)!
	if !contains_part(s.midi_channel_usage[channel], part.origin) {
		s.midi_channel_usage[channel] << part.origin
	}
	return channel
}
