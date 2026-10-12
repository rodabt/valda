module playback

import math
import engine

// render_wav renders messages offline (faster than real time) to 16-bit stereo
// PCM WAV bytes. The engine must have been opened with engine.open_offline.
pub fn render_wav(msgs Messages, tail_ms int) []u8 {
	sample_rate := engine.sample_rate()

	for msg in msgs.timeline() {
		frame := engine.ms_to_frames(f64(msg.offset))
		match msg.kind {
			.note_on { engine.schedule(frame, .note_on, msg.channel, msg.a, msg.b) }
			.note_off { engine.schedule(frame, .note_off, msg.channel, msg.a, msg.b) }
			.program { engine.schedule(frame, .program, msg.channel, msg.a, 0) }
			.control { engine.schedule(frame, .control, msg.channel, msg.a, msg.b) }
			.tempo {}
		}
	}

	block := 1024
	end_frame := engine.ms_to_frames(f64(msgs.length))
	max_frame := end_frame + engine.ms_to_frames(f64(tail_ms))

	mut buffer := []f32{len: block * 2}
	mut pcm := []u8{cap: int(max_frame) * 4}

	for {
		now := engine.now_frames()
		if now >= max_frame || (now >= end_frame && engine.pending() == 0
			&& engine.active_voices() == 0) {
			break
		}
		engine.render_offline(mut buffer, block)
		for sample in buffer {
			v := i16(math.clamp(sample, -1.0, 1.0) * 32767.0)
			pcm << u8(v & 0xFF)
			pcm << u8((v >> 8) & 0xFF)
		}
	}

	return wav_bytes(pcm, sample_rate, 2)
}

fn le32(v u32) []u8 {
	return [u8(v), u8(v >> 8), u8(v >> 16), u8(v >> 24)]
}

fn le16(v u16) []u8 {
	return [u8(v), u8(v >> 8)]
}

fn wav_bytes(pcm []u8, sample_rate int, channels int) []u8 {
	byte_rate := u32(sample_rate * channels * 2)
	mut out := []u8{cap: pcm.len + 44}
	out << 'RIFF'.bytes()
	out << le32(u32(36 + pcm.len))
	out << 'WAVE'.bytes()
	out << 'fmt '.bytes()
	out << le32(16)
	out << le16(1) // PCM
	out << le16(u16(channels))
	out << le32(u32(sample_rate))
	out << le32(byte_rate)
	out << le16(u16(channels * 2))
	out << le16(16)
	out << 'data'.bytes()
	out << le32(u32(pcm.len))
	out << pcm
	return out
}
