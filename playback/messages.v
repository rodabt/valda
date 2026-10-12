module playback

import math
import model

// MsgKind is a kind of timed message produced from a score.
pub enum MsgKind {
	note_on
	note_off
	program
	control
	tempo
}

pub const cc_panning = 10
pub const cc_expression = 11

// TimedMessage is a MIDI-level message at an offset (ms) relative to the start
// of a transmission. This is the in-process equivalent of the OSC messages that
// Alda's client sends to its player process.
pub struct TimedMessage {
pub:
	offset int // ms, relative
	track  int // 0 for system (tempo) messages
	// The part's track number, by part ID. Unlike `track`, this is stable across
	// voice groups (which replace parts with their last voice), so each part's
	// messages share one number. Used for multi-track MIDI export.
	part_track int
	kind       MsgKind
	channel    int
	a          int // note number / program / controller
	b          int // velocity / controller value
	bpm        f64 // tempo messages only
	// For note-on messages: offset + full (not audible) duration, used to line
	// up subsequent input in the REPL after the notes already scheduled.
	end int
}

@[params]
pub struct Options {
pub:
	// A time marking (e.g. 0:30) or marker from which to start.
	from string
	// A time marking (e.g. 1:00) or marker at which to end.
	to         string
	from_index int
	to_index   int = -1
	// Part ID => offset subtracted from that part's events, so that new REPL
	// input lines up after the previously transmitted events.
	sync_offsets map[string]f64
}

fn round_ms(x f64) int {
	return int(math.round(x))
}

fn tempo_messages(score &model.Score, start_offset f64, end_offset f64) []TimedMessage {
	itinerary := score.tempo_itinerary()

	mut first_tempo_offset := 0.0
	for entry in itinerary {
		if entry.offset > start_offset {
			break
		}
		first_tempo_offset = entry.offset
	}

	mut messages := []TimedMessage{}
	for entry in itinerary {
		if entry.offset < first_tempo_offset {
			continue
		}
		if entry.offset >= end_offset {
			break
		}
		offset := math.max(entry.offset - start_offset, 0)
		messages << TimedMessage{
			offset: round_ms(offset)
			kind:   .tempo
			bpm:    f64(f32(entry.tempo))
		}
	}
	return messages
}

// Messages are the result of converting (part of) a score into timed
// messages.
pub struct Messages {
pub:
	tempo []TimedMessage
	// Track number => messages for that track, in generation order.
	tracks map[int][]TimedMessage
	// Track number => part ID
	track_parts map[int]string
	// Part track number (see TimedMessage.part_track) => display name: the
	// part's alias, or its instrument name.
	track_names map[int]string
	// The offset at which the last audible note ends, relative.
	length int
}

// score_messages converts a score's note events into timed MIDI messages,
// following the same rules as Alda's OSC transmitter: program changes,
// expression (track volume) and panning are only sent when they change on a
// channel, and notes are sent with their audible duration.
pub fn score_messages(score &model.Score, opts Options) !Messages {
	to_index := if opts.to_index == -1 { score.events.len } else { opts.to_index }
	mut events := score.events[opts.from_index..to_index].clone()
	events.sort_with_compare(fn (a &model.NoteEvent, b &model.NoteEvent) int {
		if a.offset < b.offset {
			return -1
		}
		if a.offset > b.offset {
			return 1
		}
		return 0
	})

	mut start_offset := 0.0
	mut end_offset := math.max_f64
	if opts.from != '' {
		start_offset = score.interpret_offset_reference(opts.from)!
	}
	if opts.to != '' {
		end_offset = score.interpret_offset_reference(opts.to)!
	}

	tempo := if opts.sync_offsets.len == 0 {
		tempo_messages(score, start_offset, end_offset)
	} else {
		[]TimedMessage{}
	}

	tracks := score.tracks()
	mut part_tracks := map[string]int{}
	mut part_names := map[string]string{}
	for i, part in score.parts {
		part_tracks[part.id] = i + 1
		part_names[part.id] = part_display_name(score, part)
	}
	mut by_track := map[int][]TimedMessage{}
	mut track_parts := map[int]string{}
	mut track_names := map[int]string{}
	mut channel_patch := map[int]int{}
	mut channel_volume := map[int]f64{}
	mut channel_panning := map[int]f64{}
	mut length := 0.0

	for event in events {
		if event.offset < start_offset {
			continue
		}
		if event.offset >= end_offset {
			break
		}

		track := tracks[model.part_key(event.part)] or { 0 }
		track_parts[track] = event.part.id
		part_track := part_tracks[event.part.id] or { 0 }
		track_names[part_track] = part_names[event.part.id] or { event.part.name }
		channel := event.midi_channel

		mut offset := event.offset - start_offset
		offset -= opts.sync_offsets[event.part.id] or { 0.0 }
		if offset < 0 {
			offset = 0
		}
		off := round_ms(offset)

		mut msgs := by_track[track] or { []TimedMessage{} }

		// Channel 9 is percussion; there is no patch to set.
		if channel != 9 {
			patch := event.part.stock_instrument.patch_number
			if current := channel_patch[channel] {
				if current != patch {
					channel_patch[channel] = patch
					msgs << program_msg(track, part_track, channel, off, patch)
				}
			} else {
				channel_patch[channel] = patch
				msgs << program_msg(track, part_track, channel, off, patch)
			}
		}

		if channel !in channel_volume || channel_volume[channel] != event.track_volume {
			channel_volume[channel] = event.track_volume
			msgs << TimedMessage{
				offset:     off
				track:      track
				part_track: part_track
				kind:       .control
				channel:    channel
				a:          cc_expression
				b:          round_ms(event.track_volume * 127)
			}
		}

		if channel !in channel_panning || channel_panning[channel] != event.panning {
			channel_panning[channel] = event.panning
			msgs << TimedMessage{
				offset:     off
				track:      track
				part_track: part_track
				kind:       .control
				channel:    channel
				a:          cc_panning
				b:          round_ms(event.panning * 127)
			}
		}

		audible := round_ms(event.audible_duration)
		msgs << TimedMessage{
			offset:     off
			track:      track
			part_track: part_track
			kind:       .note_on
			channel:    channel
			a:          event.midi_note
			b:          round_ms(event.volume * 127)
			end:        off + round_ms(event.duration)
		}
		msgs << TimedMessage{
			offset:     off + audible
			track:      track
			part_track: part_track
			kind:       .note_off
			channel:    channel
			a:          event.midi_note
			b:          round_ms(event.volume * 127)
		}

		by_track[track] = msgs
		length = math.max(length, offset + event.audible_duration)
	}

	return Messages{
		tempo:       tempo
		tracks:      by_track
		track_parts: track_parts
		track_names: track_names
		length:      round_ms(length)
	}
}

// part_display_name returns the part's own alias (e.g. "lh" in `piano "lh":`),
// or its instrument name when it has none. Aliases of the form "group.part"
// are derived from group aliases, so they are skipped.
fn part_display_name(score &model.Score, part &model.Part) string {
	for alias in score.aliases_for(part) {
		if !alias.contains('.') {
			return alias
		}
	}
	return part.name
}

fn program_msg(track int, part_track int, channel int, offset int, patch int) TimedMessage {
	return TimedMessage{
		offset:     offset
		track:      track
		part_track: part_track
		kind:       .program
		channel:    channel
		a:          patch
	}
}

// sorted_tracks returns the track numbers in ascending order.
pub fn (m Messages) sorted_tracks() []int {
	mut keys := m.tracks.keys()
	keys.sort()
	return keys
}

// timeline returns all messages (tempo first, then each track's messages)
// stably sorted by offset.
pub fn (m Messages) timeline() []TimedMessage {
	mut all := m.tempo.clone()
	for track in m.sorted_tracks() {
		all << m.tracks[track]
	}
	return stable_by_offset(all)
}

// stable_by_offset sorts by offset, preserving the relative order of messages
// at the same offset (V's sort is not guaranteed to be stable).
fn stable_by_offset(msgs []TimedMessage) []TimedMessage {
	mut indexed := []IndexedMsg{cap: msgs.len}
	for i, msg in msgs {
		indexed << IndexedMsg{i, msg}
	}
	indexed.sort_with_compare(fn (a &IndexedMsg, b &IndexedMsg) int {
		if a.msg.offset != b.msg.offset {
			return a.msg.offset - b.msg.offset
		}
		return a.index - b.index
	})
	return indexed.map(it.msg)
}

struct IndexedMsg {
	index int
	msg   TimedMessage
}
