module parser

import os
import model

struct Parser {
	filename string
	input    []Token
	// When true, source context is not included in parsed nodes. Useful for
	// testing equality of ASTs, agnostic of line and column numbers.
	suppress_source_context bool
mut:
	current int
}

@[params]
pub struct ParseOptions {
pub:
	suppress_source_context bool
}

fn (p &Parser) ctx(token Token) model.AldaSourceContext {
	if p.suppress_source_context {
		return model.AldaSourceContext{}
	}
	return token.source_context
}

fn (p &Parser) peek() Token {
	return p.input[p.current]
}

fn (p &Parser) previous() Token {
	return p.input[p.current - 1]
}

// CAUTION: Panics if the current token is EOF.
fn (p &Parser) next() Token {
	return p.input[p.current + 1]
}

fn (p &Parser) check(types ...TokenType) bool {
	return p.peek().token_type in types
}

fn (mut p Parser) advance() Token {
	if !p.check(.eof) {
		p.current++
	}
	return p.previous()
}

fn (mut p Parser) match_token(types ...TokenType) ?Token {
	for t in types {
		if p.check(t) {
			return p.advance()
		}
	}
	return none
}

fn error_at_token(token Token, msg string) IError {
	return model.source_errorf(token.source_context, msg)
}

fn unexpected_token_error(token Token, context string) IError {
	ctx := if context != '' { ' ' + context } else { '' }
	text := if token.text.len > 0 { ' `${token.text}`' } else { '' }
	return error_at_token(token, 'Unexpected ${token.token_type}${text}${ctx}')
}

fn (mut p Parser) consume(token_type TokenType, context string) !Token {
	if p.check(token_type) {
		return p.advance()
	}
	return unexpected_token_error(p.peek(), context)
}

fn (mut p Parser) lisp_form(context string) !ASTNode {
	if token := p.match_token(.symbol) {
		return ASTNode{
			node_type:      .lisp_symbol_node
			source_context: p.ctx(token)
			literal:        token.text
		}
	}
	if token := p.match_token(.number) {
		return ASTNode{
			node_type:      .lisp_number_node
			source_context: p.ctx(token)
			literal:        token.literal
		}
	}
	if token := p.match_token(.string) {
		return ASTNode{
			node_type:      .lisp_string_node
			source_context: p.ctx(token)
			literal:        token.literal
		}
	}
	if _ := p.match_token(.left_paren) {
		return p.lisp_list()
	}
	return unexpected_token_error(p.peek(), context)
}

fn (mut p Parser) lisp_list() !ASTNode {
	// NB: The initial LeftParen token was already consumed.
	mut list := ASTNode{
		node_type:      .lisp_list_node
		source_context: p.ctx(p.previous())
	}

	for p.peek().token_type != .right_paren {
		token := p.peek()
		if _ := p.match_token(.eof) {
			return error_at_token(token, 'unterminated S-expression')
		}

		quote_token := p.match_token(.single_quote)
		mut form := p.lisp_form('in S-expression')!

		if qt := quote_token {
			form = ASTNode{
				node_type:      .lisp_quoted_form_node
				source_context: p.ctx(qt)
				children:       [form]
			}
		}

		list.children << form
	}

	p.consume(.right_paren, 'in S-expression')!
	return list
}

fn (mut p Parser) sexp() !ASTNode {
	list := p.lisp_list()!
	return p.single_or_repeated(list)
}

fn (mut p Parser) part_declaration() !ASTNode {
	// NB: The initial Name token was already consumed.
	name_token := p.previous()

	mut names_node := ASTNode{
		node_type:      .part_names_node
		source_context: p.ctx(name_token)
		children:       [p.part_name_node(name_token)]
	}

	for {
		if _ := p.match_token(.separator) {
			name := p.consume(.name, 'in part declaration')!
			names_node.children << p.part_name_node(name)
		} else {
			break
		}
	}

	mut decl := ASTNode{
		node_type:      .part_declaration_node
		source_context: p.ctx(name_token)
		children:       [names_node]
	}

	if alias := p.match_token(.alias) {
		decl.children << ASTNode{
			node_type:      .part_alias_node
			source_context: p.ctx(alias)
			literal:        alias.literal
		}
	}

	p.consume(.colon, 'in part declaration')!
	return decl
}

fn (p &Parser) part_name_node(token Token) ASTNode {
	return ASTNode{
		node_type:      .part_name_node
		source_context: p.ctx(token)
		literal:        token.text
	}
}

fn (p &Parser) looks_like_part_declaration() bool {
	current := p.peek().token_type
	if current == .eof {
		return false
	}
	next := p.next().token_type
	return current == .name && next in [.alias, .separator, .colon]
}

fn (mut p Parser) part_events() !ASTNode {
	mut events := ASTNode{
		node_type:      .event_sequence_node
		source_context: p.ctx(p.peek())
	}

	// Keep consuming events until we reach a part declaration or EOF.
	for !p.check(.eof) && !p.looks_like_part_declaration() {
		events.children << p.inner_event()!
	}

	return events
}

fn (mut p Parser) part() !ASTNode {
	// NB: The initial Name token was already consumed.
	name_token := p.previous()
	decl := p.part_declaration()!
	events := p.part_events()!
	return ASTNode{
		node_type:      .part_node
		source_context: p.ctx(name_token)
		children:       [decl, events]
	}
}

// An "implicit part" can contain initial variable definitions and
// S-expressions at the top of the file (e.g. global attributes), or events
// without a part declaration, e.g. REPL input that continues a score.
fn (mut p Parser) implicit_part() !ASTNode {
	events := p.part_events()!
	return ASTNode{
		node_type:      .implicit_part_node
		source_context: events.source_context
		children:       [events]
	}
}

fn (mut p Parser) variable_definition() !ASTNode {
	// NB: The initial Name token was already consumed.
	name_token := p.previous()

	name_node := ASTNode{
		node_type:      .variable_name_node
		source_context: p.ctx(name_token)
		literal:        name_token.text
	}

	definition_line := name_token.source_context.line

	equals_token := p.consume(.equals, 'in variable definition')!

	if p.check(.eof) || p.peek().source_context.line > definition_line {
		return model.source_errorf(name_token.source_context, "there must be at least one event on the same line as the '='")
	}

	mut events := ASTNode{
		node_type:      .event_sequence_node
		source_context: p.ctx(p.peek())
	}

	for p.peek().source_context.line == definition_line {
		if p.peek().token_type == .eof {
			break
		}
		events.children << p.inner_event()!
	}

	return ASTNode{
		node_type:      .variable_definition_node
		source_context: p.ctx(equals_token)
		children:       [name_node, events]
	}
}

fn (mut p Parser) single_or_repeated(node ASTNode) ASTNode {
	if token := p.match_token(.repeat) {
		return ASTNode{
			node_type:      .repeat_node
			source_context: p.ctx(token)
			children:       [node, ASTNode{
				node_type: .times_node
				literal:   token.literal
			}]
		}
	}
	return node
}

fn (mut p Parser) variable_definition_or_reference() !ASTNode {
	if p.check(.equals) {
		return p.variable_definition()
	}

	name_token := p.previous()
	return p.single_or_repeated(ASTNode{
		node_type:      .variable_reference_node
		source_context: p.ctx(name_token)
		literal:        name_token.text
	})
}

fn (p &Parser) octave_set() ASTNode {
	token := p.previous()
	return ASTNode{
		node_type:      .octave_set_node
		source_context: p.ctx(token)
		literal:        token.literal
	}
}

fn (mut p Parser) match_duration_component() ?Token {
	return p.match_token(.note_length, .note_length_ms, .note_length_seconds)
}

fn (p &Parser) duration_component() ASTNode {
	// NB: The duration component token was already consumed.
	token := p.previous()

	match token.token_type {
		.note_length {
			mut node := ASTNode{
				node_type:      .note_length_node
				source_context: p.ctx(token)
				children:       [
					ASTNode{
						node_type: .denominator_node
						literal:   token.denominator
					},
				]
			}
			if token.dots > 0 {
				node.children << ASTNode{
					node_type: .dots_node
					literal:   token.dots
				}
			}
			return node
		}
		.note_length_ms {
			return ASTNode{
				node_type:      .note_length_ms_node
				source_context: p.ctx(token)
				literal:        token.literal
			}
		}
		.note_length_seconds {
			return ASTNode{
				node_type:      .note_length_seconds_node
				source_context: p.ctx(token)
				literal:        token.literal
			}
		}
		else {
			return ASTNode{}
		}
	}
}

fn (p &Parser) barline_node(token Token) ASTNode {
	return ASTNode{
		node_type:      .barline_node
		source_context: p.ctx(token)
	}
}

fn duration_node(components []ASTNode) ASTNode {
	return ASTNode{
		node_type:      .duration_node
		source_context: components[0].source_context
		children:       components
	}
}

fn (mut p Parser) duration() ASTNode {
	// NB: The initial duration component token was already consumed.
	mut components := [p.duration_component()]

	for {
		for {
			if token := p.match_token(.barline) {
				components << p.barline_node(token)
			} else {
				break
			}
		}

		// If we encounter a tie that turns out to be a slur (i.e. it isn't
		// followed by a note length), backtrack to here and let the slur be
		// consumed as part of e.g. a note.
		before_ties := p.current

		if _ := p.match_token(.tie) {
		} else {
			return duration_node(components)
		}

		// Barlines are only added if we don't backtrack.
		mut barlines := []ASTNode{}
		for {
			if token := p.match_token(.barline) {
				barlines << p.barline_node(token)
			} else {
				break
			}
		}

		// Allow extraneous ties, e.g. on either side of a barline.
		for {
			if _ := p.match_token(.tie) {
			} else {
				break
			}
		}

		if _ := p.match_duration_component() {
		} else {
			p.current = before_ties
			return duration_node(components)
		}

		components << barlines
		components << p.duration_component()
	}
	return duration_node(components)
}

fn (mut p Parser) note() !ASTNode {
	// NB: The initial NoteLetter token was already consumed.
	letter_token := p.previous()

	mut laa_node := ASTNode{
		node_type:      .note_letter_and_accidentals_node
		source_context: p.ctx(letter_token)
		children:       [
			ASTNode{
				node_type:      .note_letter_node
				source_context: p.ctx(letter_token)
				literal:        letter_token.literal
			},
		]
	}

	mut accidentals := []ASTNode{}
	for {
		if token := p.match_token(.flat) {
			accidentals << ASTNode{
				node_type:      .flat_node
				source_context: p.ctx(token)
			}
		} else if token := p.match_token(.natural) {
			accidentals << ASTNode{
				node_type:      .natural_node
				source_context: p.ctx(token)
			}
		} else if token := p.match_token(.sharp) {
			accidentals << ASTNode{
				node_type:      .sharp_node
				source_context: p.ctx(token)
			}
		} else {
			break
		}
	}

	if accidentals.len > 0 {
		laa_node.children << ASTNode{
			node_type:      .note_accidentals_node
			source_context: accidentals[0].source_context
			children:       accidentals
		}
	}

	mut note_node := ASTNode{
		node_type:      .note_node
		source_context: p.ctx(letter_token)
		children:       [laa_node]
	}

	if _ := p.match_duration_component() {
		note_node.children << p.duration()
	}

	if tie := p.match_token(.tie) {
		note_node.children << ASTNode{
			node_type:      .tie_node
			source_context: p.ctx(tie)
		}
	}

	return note_node
}

fn (mut p Parser) rest() ASTNode {
	token := p.previous()
	mut rest := ASTNode{
		node_type:      .rest_node
		source_context: p.ctx(token)
	}
	if _ := p.match_duration_component() {
		rest.children = [p.duration()]
	}
	return rest
}

fn (mut p Parser) note_or_rest() !ASTNode {
	letter := p.previous()
	return match letter.token_type {
		.note_letter { p.note()! }
		.rest_letter { p.rest() }
		else { unexpected_token_error(letter, 'in note/rest') }
	}
}

fn (mut p Parser) nodes_between_notes_in_chord() ![]ASTNode {
	mut updates := []ASTNode{}
	for {
		if token := p.match_token(.octave_up) {
			updates << ASTNode{
				node_type:      .octave_up_node
				source_context: p.ctx(token)
			}
		} else if token := p.match_token(.octave_down) {
			updates << ASTNode{
				node_type:      .octave_down_node
				source_context: p.ctx(token)
			}
		} else if _ := p.match_token(.octave_set) {
			updates << p.octave_set()
		} else if _ := p.match_token(.left_paren) {
			updates << p.lisp_list()!
		} else {
			return updates
		}
	}
	return updates
}

// note_rest_or_chord parses a note or chord. A chord can contain multiple notes
// and rests, as well as attribute changes in between them.
fn (mut p Parser) note_rest_or_chord() !ASTNode {
	mut all_nodes := []ASTNode{}
	mut repeat_times := 0
	mut repeat_context := model.AldaSourceContext{}

	for {
		note_or_rest := p.note_or_rest()!

		if token := p.match_token(.repeat) {
			all_nodes << note_or_rest
			repeat_times = token.literal as int
			repeat_context = p.ctx(token)
			break
		}

		mut nodes := [note_or_rest]

		// If we parse a note followed by e.g. an octave change that isn't
		// followed by `/`, backtrack so that the octave change is parsed
		// separately by the next invocation of inner_event.
		backtrack_position := p.current

		before_separator := p.nodes_between_notes_in_chord()!

		if _ := p.match_token(.separator) {
		} else {
			p.current = backtrack_position
			all_nodes << nodes
			break
		}

		nodes << before_separator
		nodes << p.nodes_between_notes_in_chord()!
		all_nodes << nodes

		if _ := p.match_token(.note_letter, .rest_letter) {
		} else {
			return unexpected_token_error(p.peek(), 'in chord')
		}
	}

	notes_count := all_nodes.filter(it.node_type in [.note_node, .rest_node]).len

	if notes_count > 1 {
		all_nodes = [
			ASTNode{
				node_type:      .chord_node
				source_context: all_nodes[0].source_context
				children:       all_nodes
			},
		]
	}

	if repeat_times > 0 {
		if all_nodes.len != 1 {
			panic('Expected a single node in ${all_nodes}')
		}
		return ASTNode{
			node_type:      .repeat_node
			source_context: repeat_context
			children:       [all_nodes[0], ASTNode{
				node_type: .times_node
				literal:   repeat_times
			}]
		}
	}

	return all_nodes[0]
}

fn (mut p Parser) event_seq() !ASTNode {
	open_token := p.previous()
	mut event_nodes := []ASTNode{}

	for p.peek().token_type != .event_seq_close {
		token := p.peek()
		if _ := p.match_token(.eof) {
			return error_at_token(token, 'unterminated event sequence')
		}

		mut event_node := p.inner_event()!

		if rep := p.match_token(.repetitions) {
			mut reps := ASTNode{
				node_type:      .repetitions_node
				source_context: p.ctx(rep)
			}
			for r in rep.ranges {
				reps.children << ASTNode{
					node_type: .repetition_range_node
					children:  [
						ASTNode{
							node_type: .first_repetition_node
							literal:   r.first
						},
						ASTNode{
							node_type: .last_repetition_node
							literal:   r.last
						},
					]
				}
			}
			event_node = ASTNode{
				node_type:      .on_repetitions_node
				source_context: p.ctx(rep)
				children:       [event_node, reps]
			}
		}

		event_nodes << event_node
	}

	p.consume(.event_seq_close, 'in event sequence')!

	return p.single_or_repeated(ASTNode{
		node_type:      .event_sequence_node
		source_context: p.ctx(open_token)
		children:       event_nodes
	})
}

fn (mut p Parser) cram() !ASTNode {
	open_token := p.previous()
	mut events := []ASTNode{}

	for p.peek().token_type != .cram_close {
		token := p.peek()
		if _ := p.match_token(.eof) {
			return error_at_token(token, 'unterminated cram expression')
		}
		events << p.inner_event()!
	}

	p.consume(.cram_close, 'in cram expression')!

	if events.len == 0 {
		return error_at_token(open_token, 'empty cram expression')
	}

	mut cram := ASTNode{
		node_type:      .cram_node
		source_context: p.ctx(open_token)
		children:       [
			ASTNode{
				node_type:      .event_sequence_node
				source_context: events[0].source_context
				children:       events
			},
		]
	}

	if _ := p.match_duration_component() {
		cram.children << p.duration()
	}

	return p.single_or_repeated(cram)
}

fn (mut p Parser) voice() !ASTNode {
	// NB: The VoiceMarker token was already consumed.
	token := p.previous()
	number := ASTNode{
		node_type:      .voice_number_node
		source_context: p.ctx(token)
		literal:        token.literal
	}

	mut events := ASTNode{
		node_type:      .event_sequence_node
		source_context: p.ctx(p.peek())
	}

	// Consume events until another voice marker, a new part, EOF, or a closing
	// ] or }.
	for !p.check(.eof, .voice_marker, .event_seq_close, .cram_close)
		&& !p.looks_like_part_declaration() {
		events.children << p.inner_event()!
	}

	return ASTNode{
		node_type:      .voice_node
		source_context: number.source_context
		children:       [number, events]
	}
}

fn (mut p Parser) voice_group() !ASTNode {
	first := p.previous()
	mut group := ASTNode{
		node_type:      .voice_group_node
		source_context: p.ctx(first)
	}

	for {
		group.children << p.voice()!

		marker := p.match_token(.voice_marker) or { break }

		if marker.literal as int == 0 {
			group.children << ASTNode{
				node_type:      .voice_group_end_marker_node
				source_context: p.ctx(marker)
			}
			break
		}
	}

	return group
}

fn (mut p Parser) simple_node(node_type NodeType, token Token) ASTNode {
	return ASTNode{
		node_type:      node_type
		source_context: p.ctx(token)
		literal:        token.literal
	}
}

fn (mut p Parser) inner_event() !ASTNode {
	if _ := p.match_token(.left_paren) {
		return p.sexp()
	}
	if _ := p.match_token(.name) {
		return p.variable_definition_or_reference()
	}
	if _ := p.match_token(.octave_set) {
		return p.octave_set()
	}
	if token := p.match_token(.octave_up) {
		return p.simple_node(.octave_up_node, token)
	}
	if token := p.match_token(.octave_down) {
		return p.simple_node(.octave_down_node, token)
	}
	if _ := p.match_token(.note_letter, .rest_letter) {
		return p.note_rest_or_chord()
	}
	if token := p.match_token(.barline) {
		return p.barline_node(token)
	}
	if _ := p.match_token(.event_seq_open) {
		return p.event_seq()
	}
	if _ := p.match_token(.cram_open) {
		return p.cram()
	}
	if _ := p.match_token(.voice_marker) {
		return p.voice_group()
	}
	if token := p.match_token(.marker) {
		return p.simple_node(.marker_node, token)
	}
	if token := p.match_token(.at_marker) {
		return p.simple_node(.at_marker_node, token)
	}
	return unexpected_token_error(p.peek(), 'in inner events')
}

fn (mut p Parser) top_level() !ASTNode {
	if p.looks_like_part_declaration() {
		p.consume(.name, 'in part declaration')!
		return p.part()
	}
	return p.implicit_part()
}

fn (mut p Parser) parse_ast() !ASTNode {
	mut root := ASTNode{
		node_type: .root_node
	}
	for p.peek().token_type != .eof {
		root.children << p.top_level()!
	}
	return root
}

// parse parses a string of input into a root ASTNode.
pub fn parse(filepath string, input string, opts ParseOptions) !ASTNode {
	tokens := scan(filepath, input)!
	mut p := Parser{
		filename:                filepath
		input:                   tokens
		suppress_source_context: opts.suppress_source_context
	}
	return p.parse_ast()
}

// parse_string parses a string of input.
pub fn parse_string(input string) !ASTNode {
	return parse('', input)
}

// parse_file reads a file and parses the input.
pub fn parse_file(filepath string) !ASTNode {
	if !os.exists(filepath) {
		return error("Failed to open ${filepath}. The file does not seem to exist.

Please check that you haven't misspelled the file name, etc.")
	}
	return parse(filepath, os.read_file(filepath)!)
}

// parse_updates parses a string of input and returns the resulting score
// updates.
pub fn parse_updates(filepath string, input string) ![]model.ScoreUpdate {
	ast := parse(filepath, input)!
	return ast.updates()
}

// init plugs the parser into the model, for the `alda-code` Lisp function.
fn init() {
	model.set_alda_code_parser(fn (code string) ![]model.ScoreUpdate {
		return parse_updates('', code)
	})
}
