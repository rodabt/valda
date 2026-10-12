module parser

fn types(src string) []TokenType {
	tokens := scan('', src) or { panic(err) }
	return tokens.map(it.token_type)
}

fn test_scanner_basics() {
	assert types('piano: c8 d+ e-4. r') == [.name, .colon, .note_letter, .note_length, .note_letter,
		.sharp, .note_letter, .flat, .note_length, .rest_letter, .eof]
	assert types('o4 > < V1: | ~ /') == [.octave_set, .octave_up, .octave_down, .voice_marker,
		.barline, .tie, .separator, .eof]
	assert types('(tempo! 120) %m @m') == [.left_paren, .symbol, .number, .right_paren, .marker,
		.at_marker, .eof]
	assert types("[c d]*2 '1-2,4") == [.event_seq_open, .note_letter, .note_letter, .event_seq_close,
		.repeat, .repetitions, .eof]
	assert types('c500ms d2s') == [.note_letter, .note_length_ms, .note_letter, .note_length_seconds,
		.eof]
}

fn test_scanner_literals() {
	tokens := scan('', 'c4.. o5 V2: *3') or { panic(err) }
	assert tokens[1].denominator == 4 && tokens[1].dots == 2
	assert tokens[2].literal as int == 5
	assert tokens[3].literal as int == 2
	assert tokens[4].literal as int == 3
}

fn test_comments_are_ignored() {
	assert types('c # this is a comment\nd') == [.note_letter, .note_letter, .eof]
}

fn test_scanner_errors() {
	scan('', 'piano: c d $') or {
		assert err.msg() == "<no file>:1:12 Unexpected '$' at the top level"
		return
	}
	assert false
}

fn test_parse_chord_vs_octave_backtracking() {
	ast := parse('', 'c/e/>g c > d', suppress_source_context: true) or { panic(err) }
	events := ast.children[0].children[0].children
	assert events.map(it.node_type) == [.chord_node, .note_node, .octave_up_node, .note_node]
}

fn test_parse_tie_vs_slur() {
	// A tie followed by a note length extends the duration...
	ast := parse_string('c4~4') or { panic(err) }
	note := ast.children[0].children[0].children[0]
	assert note.children[1].node_type == .duration_node
	assert note.children[1].children.len == 2
	// ...otherwise it's a slur.
	slurred := (parse_string('c4~ d') or { panic(err) }).children[0].children[0].children[0]
	assert slurred.children.last().node_type == .tie_node
}

fn test_parse_variable_definition_requires_events_on_same_line() {
	parse_string('riff =\nc') or {
		assert err.msg().contains("there must be at least one event on the same line as the '='")
		return
	}
	assert false
}

fn test_parse_errors() {
	cases := {
		'piano: [c d':     'unterminated event sequence'
		'piano: (tempo 1': 'unterminated S-expression'
		'piano: c d e*':   'Unexpected newline in repeat'
		'piano: {}':       'empty cram expression'
	}
	for src, expected in cases {
		parse_string(src + '\n') or {
			assert err.msg().contains(expected), src
			continue
		}
		assert false, src
	}
}

fn test_updates_round_trip_through_generated_ast() {
	src := 'piano "p": (key-signature "f+") o4 c8 d+ e_ | f2. [g a]*2 {c d e}4 V1: c V2: e V0: r4~|8'
	updates := parse_updates('', src) or { panic(err) }
	generated := generate_ast(updates) or { panic(err) }
	text := format_ast(generated) or { panic(err) }
	assert (parse_updates('', text) or { panic(err) }).len == updates.len
}
