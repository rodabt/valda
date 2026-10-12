module smf

import playback

fn test_var_len() {
	for value, expected in {
		i64(0):     [u8(0x00)]
		0x40:       [u8(0x40)]
		0x7F:       [u8(0x7F)]
		0x80:       [u8(0x81), 0x00]
		0x2000:     [u8(0xC0), 0x00]
		0x3FFF:     [u8(0xFF), 0x7F]
		0x0FFFFFFF: [u8(0xFF), 0xFF, 0xFF, 0x7F]
	} {
		mut out := []u8{}
		write_var_len(mut out, value)
		assert out == expected, '${value}'
	}
}

fn test_tempo_map() {
	mut tm := TempoMap{}
	// At 120 bpm, 128 ticks per quarter note = 500ms.
	assert tm.ms_to_ticks(500) == 128
	tm.add(TempoEntry{1000, 60, tm.ms_to_ticks(1000)})
	// After 1000ms (256 ticks), a quarter note takes 1000ms.
	assert tm.ms_to_ticks(2000) == 256 + 128
}

fn test_encode() {
	msgs := playback.Messages{
		tempo:  [playback.TimedMessage{
			kind: .tempo
			bpm:  120
		}]
		tracks: {
			1: [
				playback.TimedMessage{
					kind: .program
					a:    40
				},
				playback.TimedMessage{
					kind: .note_on
					a:    60
					b:    100
				},
				playback.TimedMessage{
					offset: 500
					kind:   .note_off
					a:      60
					b:      100
				},
			]
		}
	}
	data := encode(msgs)
	assert data[..4].bytestr() == 'MThd'
	assert data[8..14] == [u8(0), 0, 0, 1, 0, 128]
	assert data[14..18].bytestr() == 'MTrk'
	track := data[22..]
	// tempo meta (500000 us per quarter), program change, note on, note off
	// (after 128 ticks), end of track.
	assert track == [u8(0), 0xFF, 0x51, 3, 0x07, 0xA1, 0x20, 0, 0xC0, 40, 0, 0x90, 60, 100, 0x81,
		0x00, 0x80, 60, 100, 0, 0xFF, 0x2F, 0]
}

fn test_encode_format1() {
	note := fn (offset int, kind playback.MsgKind, channel int, key int) playback.TimedMessage {
		return playback.TimedMessage{
			offset:     offset
			track:      channel + 1
			part_track: channel + 1
			kind:       kind
			channel:    channel
			a:          key
			b:          100
		}
	}
	msgs := playback.Messages{
		tempo:       [playback.TimedMessage{
			kind: .tempo
			bpm:  120
		}]
		tracks:      {
			2: [note(0, .note_on, 1, 64), note(500, .note_off, 1, 64)]
			1: [note(0, .note_on, 0, 60), note(500, .note_off, 0, 60)]
		}
		track_names: {
			1: 'lh'
			2: 'violin'
		}
	}
	data := encode(msgs, format: 1)
	assert data[..4].bytestr() == 'MThd'
	// format 1, 3 tracks, 128 ticks per quarter note
	assert data[8..14] == [u8(0), 1, 0, 3, 0, 128]

	mut tracks := [][]u8{}
	mut i := 14
	for i < data.len {
		assert data[i..i + 4].bytestr() == 'MTrk'
		len := int(u32(data[i + 4]) << 24 | u32(data[i + 5]) << 16 | u32(data[i + 6]) << 8 | u32(data[
			i + 7]))
		tracks << data[i + 8..i + 8 + len]
		i += 8 + len
	}
	assert i == data.len
	assert tracks.len == 3
	// The tempo track holds only the tempo.
	assert tracks[0] == [u8(0), 0xFF, 0x51, 3, 0x07, 0xA1, 0x20, 0, 0xFF, 0x2F, 0]
	// Part tracks: name, note on, note off after 128 ticks, end of track.
	assert tracks[1] == [u8(0), 0xFF, 0x03, 2, `l`, `h`, 0, 0x90, 60, 100, 0x81, 0x00, 0x80, 60,
		100, 0, 0xFF, 0x2F, 0]
	assert tracks[2] == [u8(0), 0xFF, 0x03, 6, `v`, `i`, `o`, `l`, `i`, `n`, 0, 0x91, 64, 100,
		0x81, 0x00, 0x81, 64, 100, 0, 0xFF, 0x2F, 0]
}

fn test_format0_is_default() {
	msgs := playback.Messages{
		tracks: {
			1: [playback.TimedMessage{
				kind: .note_on
				a:    60
				b:    100
			}]
		}
	}
	assert encode(msgs) == encode(msgs, format: 0)
	assert encode(msgs)[8..12] == [u8(0), 0, 0, 1]
}
