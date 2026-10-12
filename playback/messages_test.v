module playback

import model
import parser

fn test_track_names() {
	mut score := model.new_score()
	score.update(...parser.parse_updates('', 'piano "lh": c d\nviolin: e f')!)!
	msgs := score_messages(score)!
	assert msgs.track_names == {
		1: 'lh'
		2: 'violin'
	}
}

fn test_track_names_skip_group_aliases() {
	mut score := model.new_score()
	score.update(...parser.parse_updates('', 'violin/viola "strings": c d')!)!
	msgs := score_messages(score)!
	assert msgs.track_names == {
		1: 'violin'
		2: 'viola'
	}
}

// Voice groups replace the part, so notes before and inside the group used to
// end up on different tracks. They must share a part track and name.
fn test_part_tracks_survive_voice_groups() {
	mut score := model.new_score()
	score.update(...parser.parse_updates('', 'cello "main": c V1: e V2: g V0: a\nviolin: b')!)!
	msgs := score_messages(score)!
	mut part_tracks := map[int]int{}
	for _, track_msgs in msgs.tracks {
		for msg in track_msgs {
			if msg.kind == .note_on {
				part_tracks[msg.a] = msg.part_track
			}
		}
	}
	// The cello's four notes share track 1; the violin's note is on track 2.
	assert part_tracks.values().filter(it == 1).len == 4
	assert part_tracks.values().filter(it == 2).len == 1
	assert msgs.track_names == {
		1: 'main'
		2: 'violin'
	}
}
