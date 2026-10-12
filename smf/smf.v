module smf

import math
import playback

// Writes Standard MIDI Files the way Alda's player does: format 0, a single
// track, 128 ticks per quarter note, tempo changes as Set Tempo meta events.
// Format 1 (opt-in) puts the tempo changes in a first track and each part in
// a track of its own, named after the part.

pub const resolution = 128

struct TempoEntry {
	offset_ms f64
	tempo     f64
	ticks     i64
}

struct TempoMap {
mut:
	entries []TempoEntry = [TempoEntry{0, 120, 0}]
}

fn (tm &TempoMap) entry_at_ms(offset_ms f64) TempoEntry {
	mut result := tm.entries[0]
	for entry in tm.entries {
		if entry.offset_ms > offset_ms {
			break
		}
		result = entry
	}
	return result
}

// ms_to_ticks converts a millisecond offset to ticks, taking into account the
// whole history of tempo changes up to that point.
fn (tm &TempoMap) ms_to_ticks(offset_ms f64) i64 {
	if offset_ms == 0 {
		return 0
	}
	entry := tm.entry_at_ms(offset_ms)
	ms_per_tick := 60000.0 / (entry.tempo * resolution)
	return i64(math.round(f64(entry.ticks) + (offset_ms - entry.offset_ms) / ms_per_tick))
}

// add keeps the entries ordered by offset; entries at the same offset go after
// the existing ones.
fn (mut tm TempoMap) add(entry TempoEntry) {
	mut i := 0
	for i < tm.entries.len && tm.entries[i].offset_ms <= entry.offset_ms {
		i++
	}
	tm.entries.insert(i, entry)
}

struct Event {
	tick i64
	data []u8
	meta bool
	// The part track (playback.TimedMessage.part_track); -1 for tempo events.
	track int
}

fn tempo_data(bpm f64) []u8 {
	uspq := int(math.round(60000000.0 / bpm))
	return [u8(0xFF), 0x51, 0x03, u8(uspq >> 16), u8(uspq >> 8), u8(uspq)]
}

// track_name_data returns a Track Name meta event, truncated so that its
// length fits in a single variable-length byte.
fn track_name_data(name string) []u8 {
	bytes := if name.len > 0x7F { name.bytes()[..0x7F] } else { name.bytes() }
	mut data := [u8(0xFF), 0x03, u8(bytes.len)]
	data << bytes
	return data
}

fn channel_data(msg playback.TimedMessage) []u8 {
	ch := u8(msg.channel & 0x0F)
	return match msg.kind {
		.note_on { [u8(0x90) | ch, u8(msg.a), u8(msg.b)] }
		.note_off { [u8(0x80) | ch, u8(msg.a), u8(msg.b)] }
		.program { [u8(0xC0) | ch, u8(msg.a)] }
		.control { [u8(0xB0) | ch, u8(msg.a), u8(msg.b)] }
		.tempo { []u8{} }
	}
}

fn write_var_len(mut out []u8, value i64) {
	mut v := u64(value)
	mut buffer := v & 0x7F
	for {
		v >>= 7
		if v == 0 {
			break
		}
		buffer <<= 8
		buffer |= (v & 0x7F) | 0x80
	}
	for {
		out << u8(buffer & 0xFF)
		if buffer & 0x80 == 0 {
			break
		}
		buffer >>= 8
	}
}

fn write_u32(mut out []u8, v u32) {
	out << [u8(v >> 24), u8(v >> 16), u8(v >> 8), u8(v)]
}

fn write_chunk(mut out []u8, id string, data []u8) {
	out << id.bytes()
	write_u32(mut out, u32(data.len))
	out << data
}

@[params]
pub struct Options {
pub:
	// 0: a single track, like Alda. 1: a tempo track followed by one track per
	// part.
	format int
}

// encode returns the bytes of a MIDI file for the given messages.
pub fn encode(msgs playback.Messages, opts Options) []u8 {
	mut tempo_map := TempoMap{}
	mut events := []Event{}

	// Tempo changes are applied first, so that note offsets can be converted to
	// ticks with awareness of every tempo change.
	for msg in msgs.tempo {
		ticks := tempo_map.ms_to_ticks(f64(msg.offset))
		tempo_map.add(TempoEntry{f64(msg.offset), msg.bpm, ticks})
		events << Event{ticks, tempo_data(msg.bpm), true, -1}
	}

	mut part_tracks := []int{}
	for track in msgs.sorted_tracks() {
		for msg in msgs.tracks[track] {
			events << Event{tempo_map.ms_to_ticks(f64(msg.offset)), channel_data(msg), false, msg.part_track}
			if msg.part_track !in part_tracks {
				part_tracks << msg.part_track
			}
		}
	}
	part_tracks.sort()

	// Like Alda, shift everything back so that the first note or control
	// change starts at tick 0.
	mut earliest := i64(-1)
	for e in events {
		if !e.meta && (e.data[0] & 0xF0 == 0x90 || e.data[0] & 0xF0 == 0xB0) {
			if earliest == -1 || e.tick < earliest {
				earliest = e.tick
			}
		}
	}
	if earliest > 0 {
		events = events.map(Event{
			...it
			tick: math.max(i64(0), it.tick - earliest)
		})
	}

	mut chunks := [][]u8{}
	if opts.format == 1 {
		chunks << encode_track(stable_sort(events.filter(it.track == -1)))
		for track in part_tracks {
			mut track_events := [
				Event{0, track_name_data(msgs.track_names[track] or { 'track ${track}' }), true, track},
			]
			track_events << events.filter(it.track == track)
			chunks << encode_track(stable_sort(track_events))
		}
	} else {
		chunks << encode_track(stable_sort(events))
	}

	mut header := []u8{}
	header << [u8(0), u8(opts.format)]
	header << [u8(chunks.len >> 8), u8(chunks.len & 0xFF)]
	header << [u8(resolution >> 8), u8(resolution & 0xFF)]

	mut out := []u8{}
	write_chunk(mut out, 'MThd', header)
	for chunk in chunks {
		write_chunk(mut out, 'MTrk', chunk)
	}
	return out
}

// encode_track returns the data of a track chunk for events sorted by tick.
fn encode_track(sorted []Event) []u8 {
	mut track_data := []u8{}
	mut last_tick := i64(0)
	mut running_status := -1
	for e in sorted {
		write_var_len(mut track_data, e.tick - last_tick)
		last_tick = e.tick
		if e.meta {
			track_data << e.data
			running_status = -1
			continue
		}
		status := int(e.data[0])
		if status != running_status {
			track_data << e.data[0]
			running_status = status
		}
		track_data << e.data[1..]
	}
	// End of track
	write_var_len(mut track_data, 0)
	track_data << [u8(0xFF), 0x2F, 0x00]
	return track_data
}

struct Indexed {
	index int
	event Event
}

fn stable_sort(events []Event) []Event {
	mut indexed := []Indexed{cap: events.len}
	for i, e in events {
		indexed << Indexed{i, e}
	}
	indexed.sort_with_compare(fn (a &Indexed, b &Indexed) int {
		if a.event.tick != b.event.tick {
			return if a.event.tick < b.event.tick { -1 } else { 1 }
		}
		return a.index - b.index
	})
	return indexed.map(it.event)
}
