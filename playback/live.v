module playback

import math
import os
import time
import engine

// How far ahead of "now" newly scheduled events start, so that the first
// notes aren't late.
pub const lead_ms = 100.0

// A Player schedules messages on the real-time engine. Like Alda's player
// process, it keeps a position for each track (the end of the last note
// scheduled on it), so that new input lines up after what's already playing.
pub struct Player {
mut:
	// Track key (part ID) => engine time (ms) where the track's last scheduled
	// note ends.
	track_ends map[string]f64
	// Engine time (ms) when the last scheduled note stops sounding.
	busy_until f64
}

// schedule schedules a batch of messages. Each track starts at the later of
// its current position and now (plus a small lead time).
pub fn (mut p Player) schedule(msgs Messages) {
	now := engine.now_ms() + lead_ms
	debug := os.getenv('VALDA_DEBUG') != ''

	for track in msgs.sorted_tracks() {
		key := msgs.track_parts[track] or { track.str() }
		start := math.max(p.track_ends[key] or { 0.0 }, now)
		if debug {
			eprintln('[${engine.now_ms():.0f}ms] track ${track} (${key}): ${msgs.tracks[track].len} messages starting at ${start:.0f}ms')
		}

		mut track_end := p.track_ends[key] or { start }
		for msg in msgs.tracks[track] {
			at := start + msg.offset
			frame := engine.ms_to_frames(at)
			match msg.kind {
				.note_on {
					engine.schedule(frame, .note_on, msg.channel, msg.a, msg.b)
					track_end = math.max(track_end, start + msg.end)
				}
				.note_off {
					engine.schedule(frame, .note_off, msg.channel, msg.a, msg.b)
					p.busy_until = math.max(p.busy_until, at)
				}
				.program {
					engine.schedule(frame, .program, msg.channel, msg.a, 0)
				}
				.control {
					engine.schedule(frame, .control, msg.channel, msg.a, msg.b)
				}
				.tempo {}
			}
		}
		p.track_ends[key] = track_end
	}
}

// stop silences everything and forgets track positions.
pub fn (mut p Player) stop() {
	engine.stop()
	p.track_ends.clear()
	p.busy_until = 0
}

// is_playing reports whether scheduled notes are still pending or sounding.
pub fn (p &Player) is_playing() bool {
	return engine.now_ms() < p.busy_until || engine.pending() > 0
}

// wait blocks until all scheduled notes have finished, then lets the release
// tails ring out (up to `tail_ms`).
pub fn (p &Player) wait(tail_ms int) {
	for p.is_playing() {
		time.sleep(20 * time.millisecond)
	}
	deadline := time.now().add(tail_ms * time.millisecond)
	for engine.active_voices() > 0 && time.now() < deadline {
		time.sleep(20 * time.millisecond)
	}
}
