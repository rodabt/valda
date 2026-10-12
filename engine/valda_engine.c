#include "valda_engine.h"

#include <stdlib.h>
#include <string.h>
#include <stdio.h>

#define TSF_IMPLEMENTATION
#include "tsf.h"

#define MA_NO_DECODING
#define MA_NO_ENCODING
#define MA_NO_GENERATION
#define MA_NO_RESOURCE_MANAGER
#define MA_NO_NODE_GRAPH
#define MA_NO_ENGINE
#define MINIAUDIO_IMPLEMENTATION
#include "miniaudio.h"

typedef struct {
	uint64_t frame;
	uint64_t seq; // insertion order, to keep same-frame events stable
	uint8_t kind, channel, a, b;
} ve_event;

static tsf* g_tsf = NULL;
static ma_device g_device;
static int g_device_started = 0;
static ma_mutex g_mutex;
static int g_mutex_ready = 0;
static int g_sample_rate = 44100;
static volatile uint64_t g_now = 0;
static uint64_t g_seq = 0;
static char g_error[512] = "";

// A sorted queue of pending events. Events in [head, count) are pending.
static ve_event* g_queue = NULL;
static int g_head = 0;
static int g_count = 0;
static int g_cap = 0;

static void set_error(const char* msg) {
	snprintf(g_error, sizeof(g_error), "%s", msg);
}

const char* ve_last_error(void) { return g_error; }

static int event_before(const ve_event* x, const ve_event* y) {
	if (x->frame != y->frame) return x->frame < y->frame;
	return x->seq < y->seq;
}

static void apply_event(const ve_event* e) {
	switch (e->kind) {
	case VE_NOTE_ON:
		if (e->b == 0) tsf_channel_note_off(g_tsf, e->channel, e->a);
		else tsf_channel_note_on(g_tsf, e->channel, e->a, e->b / 127.0f);
		break;
	case VE_NOTE_OFF:
		tsf_channel_note_off(g_tsf, e->channel, e->a);
		break;
	case VE_PROGRAM:
		tsf_channel_set_presetnumber(g_tsf, e->channel, e->a, e->channel == 9);
		break;
	case VE_CONTROL:
		tsf_channel_midi_control(g_tsf, e->channel, e->a, e->b);
		break;
	}
}

// Renders `frames` frames into `out`, applying events at the exact frame they
// are due. Must be called with the mutex held.
static void render(float* out, uint32_t frames) {
	uint64_t start = g_now;
	uint32_t done = 0;

	while (done < frames) {
		while (g_head < g_count && g_queue[g_head].frame <= start + done) {
			apply_event(&g_queue[g_head]);
			g_head++;
		}

		uint32_t until = frames;
		if (g_head < g_count && g_queue[g_head].frame < start + frames) {
			until = (uint32_t)(g_queue[g_head].frame - start);
		}

		tsf_render_float(g_tsf, out + (size_t)done * 2, (int)(until - done), 0);
		done = until;
	}

	// Reclaim consumed slots.
	if (g_head == g_count) {
		g_head = g_count = 0;
	} else if (g_head > 4096) {
		memmove(g_queue, g_queue + g_head, (size_t)(g_count - g_head) * sizeof(ve_event));
		g_count -= g_head;
		g_head = 0;
	}

	g_now = start + frames;
}

static void data_callback(ma_device* device, void* output, const void* input, ma_uint32 frames) {
	(void)device;
	(void)input;
	ma_mutex_lock(&g_mutex);
	render((float*)output, frames);
	ma_mutex_unlock(&g_mutex);
}

static int load_soundfont(const char* path, int sample_rate, float gain_db) {
	g_tsf = tsf_load_filename(path);
	if (!g_tsf) {
		char msg[512];
		snprintf(msg, sizeof(msg), "failed to load SoundFont: %s", path);
		set_error(msg);
		return 1;
	}

	g_sample_rate = sample_rate;
	tsf_set_output(g_tsf, TSF_STEREO_INTERLEAVED, sample_rate, gain_db);
	// Preallocate voices so the audio thread doesn't have to allocate.
	tsf_set_max_voices(g_tsf, 256);

	for (int ch = 0; ch < 16; ch++) {
		tsf_channel_set_presetnumber(g_tsf, ch, 0, ch == 9);
	}

	if (ma_mutex_init(&g_mutex) != MA_SUCCESS) {
		set_error("failed to initialize mutex");
		return 1;
	}
	g_mutex_ready = 1;

	return 0;
}

int ve_init_offline(const char* soundfont_path, int sample_rate, float gain_db) {
	return load_soundfont(soundfont_path, sample_rate, gain_db);
}

int ve_init(const char* soundfont_path, int sample_rate, float gain_db) {
	if (load_soundfont(soundfont_path, sample_rate, gain_db) != 0) return 1;

	ma_device_config config = ma_device_config_init(ma_device_type_playback);
	config.playback.format = ma_format_f32;
	config.playback.channels = 2;
	config.sampleRate = (ma_uint32)sample_rate;
	config.dataCallback = data_callback;
	config.periodSizeInMilliseconds = 10;

	if (ma_device_init(NULL, &config, &g_device) != MA_SUCCESS) {
		set_error("failed to open an audio playback device");
		return 1;
	}

	if (ma_device_start(&g_device) != MA_SUCCESS) {
		ma_device_uninit(&g_device);
		set_error("failed to start the audio playback device");
		return 1;
	}

	g_device_started = 1;
	return 0;
}

const char* ve_backend_name(void) {
	if (!g_device_started) return "offline";
	return ma_get_backend_name(g_device.pContext->backend);
}

void ve_schedule(uint64_t frame, int kind, int channel, int a, int b) {
	ma_mutex_lock(&g_mutex);

	if (g_count == g_cap) {
		int cap = g_cap ? g_cap * 2 : 1024;
		ve_event* q = (ve_event*)realloc(g_queue, (size_t)cap * sizeof(ve_event));
		if (!q) {
			ma_mutex_unlock(&g_mutex);
			return;
		}
		g_queue = q;
		g_cap = cap;
	}

	ve_event e;
	e.frame = frame;
	e.seq = g_seq++;
	e.kind = (uint8_t)kind;
	e.channel = (uint8_t)channel;
	e.a = (uint8_t)a;
	e.b = (uint8_t)b;

	// Events usually arrive in order, so search for the insertion point from
	// the end.
	int i = g_count;
	while (i > g_head && event_before(&e, &g_queue[i - 1])) i--;
	memmove(g_queue + i + 1, g_queue + i, (size_t)(g_count - i) * sizeof(ve_event));
	g_queue[i] = e;
	g_count++;

	ma_mutex_unlock(&g_mutex);
}

uint64_t ve_now(void) { return g_now; }

int ve_sample_rate(void) { return g_sample_rate; }

int ve_pending(void) {
	ma_mutex_lock(&g_mutex);
	int n = g_count - g_head;
	ma_mutex_unlock(&g_mutex);
	return n;
}

int ve_active_voices(void) {
	ma_mutex_lock(&g_mutex);
	int n = tsf_active_voice_count(g_tsf);
	ma_mutex_unlock(&g_mutex);
	return n;
}

void ve_stop(void) {
	ma_mutex_lock(&g_mutex);
	g_head = g_count = 0;
	for (int ch = 0; ch < 16; ch++) {
		tsf_channel_sounds_off_all(g_tsf, ch);
	}
	ma_mutex_unlock(&g_mutex);
}

void ve_render_offline(float* out, int frames) {
	ma_mutex_lock(&g_mutex);
	render(out, (uint32_t)frames);
	ma_mutex_unlock(&g_mutex);
}

void ve_close(void) {
	if (g_device_started) {
		ma_device_uninit(&g_device);
		g_device_started = 0;
	}
	if (g_tsf) {
		tsf_close(g_tsf);
		g_tsf = NULL;
	}
	if (g_mutex_ready) {
		ma_mutex_uninit(&g_mutex);
		g_mutex_ready = 0;
	}
	free(g_queue);
	g_queue = NULL;
	g_head = g_count = g_cap = 0;
}
