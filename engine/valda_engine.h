// valda_engine: a tiny real-time MIDI synth engine for valda.
//
// TinySoundFont renders General MIDI instruments from a SoundFont (.sf2), and
// miniaudio streams the result to the system's audio device. Events are
// scheduled ahead of time on a sample-accurate timeline (in frames), and the
// audio callback applies them at the exact frame they're due.
//
// Only the audio thread touches the synthesizer. Other threads communicate with
// it through the event queue, which is protected by a mutex.
#ifndef VALDA_ENGINE_H
#define VALDA_ENGINE_H

#include <stdint.h>

enum {
	VE_NOTE_ON = 0,
	VE_NOTE_OFF = 1,
	VE_PROGRAM = 2,
	VE_CONTROL = 3,
};

// Loads the SoundFont and starts the audio device. Returns 0 on success; on
// failure, ve_last_error() describes the problem.
int ve_init(const char* soundfont_path, int sample_rate, float gain_db);

// Loads the SoundFont for offline rendering only (no audio device).
int ve_init_offline(const char* soundfont_path, int sample_rate, float gain_db);

const char* ve_last_error(void);
const char* ve_backend_name(void);

// Schedules an event at an absolute frame on the engine's timeline.
void ve_schedule(uint64_t frame, int kind, int channel, int a, int b);

// The number of frames rendered so far, i.e. the current playback position.
uint64_t ve_now(void);
int ve_sample_rate(void);

// The number of events that haven't been applied yet.
int ve_pending(void);

// The number of voices currently sounding.
int ve_active_voices(void);

// Drops all pending events and silences all channels immediately.
void ve_stop(void);

// Renders `frames` frames of interleaved stereo float audio into `out`,
// applying scheduled events (offline mode only).
void ve_render_offline(float* out, int frames);

void ve_close(void);

#endif
