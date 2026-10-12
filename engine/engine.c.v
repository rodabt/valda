module engine

#flag -I @VMODROOT/thirdparty
#flag -I @VMODROOT/engine
#flag @VMODROOT/engine/valda_engine.o
#flag linux -lpthread -lm -ldl
#flag freebsd -lpthread -lm
#flag darwin -framework CoreFoundation -framework CoreAudio -framework AudioToolbox
#include "valda_engine.h"

fn C.ve_init(soundfont_path &char, sample_rate int, gain_db f32) int
fn C.ve_init_offline(soundfont_path &char, sample_rate int, gain_db f32) int
fn C.ve_last_error() &char
fn C.ve_backend_name() &char
fn C.ve_schedule(frame u64, kind int, channel int, a int, b int)
fn C.ve_now() u64
fn C.ve_sample_rate() int
fn C.ve_pending() int
fn C.ve_active_voices() int
fn C.ve_stop()
fn C.ve_render_offline(out &f32, frames int)
fn C.ve_close()

pub const default_sample_rate = 44100
pub const default_gain_db = f32(-3.0)

pub enum EventKind {
	note_on  = 0
	note_off = 1
	program  = 2
	control  = 3
}

// open loads a SoundFont and starts real-time audio output.
pub fn open(soundfont_path string) ! {
	if unsafe { C.ve_init(&char(soundfont_path.str), default_sample_rate, default_gain_db) } != 0 {
		return error(last_error())
	}
}

// open_offline loads a SoundFont for offline rendering (no audio device).
pub fn open_offline(soundfont_path string, sample_rate int) ! {
	if unsafe { C.ve_init_offline(&char(soundfont_path.str), sample_rate, default_gain_db) } != 0 {
		return error(last_error())
	}
}

fn last_error() string {
	return unsafe { cstring_to_vstring(C.ve_last_error()) }
}

// backend returns the name of the audio backend in use, e.g. "PulseAudio".
pub fn backend() string {
	return unsafe { cstring_to_vstring(C.ve_backend_name()) }
}

// schedule queues a MIDI event at an absolute frame on the engine timeline.
pub fn schedule(frame u64, kind EventKind, channel int, a int, b int) {
	C.ve_schedule(frame, int(kind), channel, a, b)
}

pub fn now_frames() u64 {
	return C.ve_now()
}

pub fn sample_rate() int {
	return C.ve_sample_rate()
}

pub fn now_ms() f64 {
	return f64(C.ve_now()) * 1000.0 / f64(C.ve_sample_rate())
}

pub fn ms_to_frames(ms f64) u64 {
	if ms <= 0 {
		return 0
	}
	return u64(ms * f64(C.ve_sample_rate()) / 1000.0 + 0.5)
}

pub fn pending() int {
	return C.ve_pending()
}

pub fn active_voices() int {
	return C.ve_active_voices()
}

// stop drops all pending events and silences all channels immediately.
pub fn stop() {
	C.ve_stop()
}

// render_offline renders interleaved stereo audio (offline mode only).
pub fn render_offline(mut out []f32, frames int) {
	unsafe { C.ve_render_offline(&f32(out.data), frames) }
}

pub fn close() {
	C.ve_close()
}
