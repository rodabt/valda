module parser

import os
import model

fn is_digit(c rune) bool {
	return c >= `0` && c <= `9`
}

fn is_letter(c rune) bool {
	return (c >= `a` && c <= `z`) || (c >= `A` && c <= `Z`)
}

// A TokenType is a type of token output by the scanner.
pub enum TokenType {
	alias
	at_marker
	barline
	colon
	cram_close
	cram_open
	eof
	equals
	event_seq_close
	event_seq_open
	flat
	integer
	left_paren
	marker
	name
	natural
	note_length
	note_length_ms
	note_length_seconds
	note_letter
	number
	octave_down
	octave_set
	octave_up
	repetitions
	rest_letter
	right_paren
	separator
	sharp
	single_quote
	string
	symbol
	tie
	repeat
	voice_marker
}

pub fn (tt TokenType) str() string {
	return match tt {
		.alias { 'alias' }
		.at_marker { 'at-marker' }
		.barline { 'barline' }
		.colon { 'colon' }
		.cram_close { 'end of cram expression' }
		.cram_open { 'start of cram expression' }
		.eof { 'EOF' }
		.equals { 'equals sign' }
		.event_seq_close { 'end of event sequence' }
		.event_seq_open { 'start of event sequence' }
		.flat { 'flat' }
		.integer { 'integer' }
		.left_paren { 'open parenthesis' }
		.marker { 'marker' }
		.name { 'name' }
		.natural { 'natural' }
		.note_length { 'note length' }
		.note_length_ms { 'note length (ms)' }
		.note_length_seconds { 'note length (s)' }
		.note_letter { 'note letter' }
		.number { 'number' }
		.octave_down { 'octave down instruction' }
		.octave_set { 'octave instruction' }
		.octave_up { 'octave up instruction' }
		.repeat { 'repeat operator' }
		.repetitions { 'repetitions' }
		.rest_letter { 'rest indicator' }
		.right_paren { 'close parenthesis' }
		.separator { 'separator' }
		.sharp { 'sharp' }
		.single_quote { 'single quote' }
		.string { 'string' }
		.symbol { 'symbol' }
		.tie { 'tie' }
		.voice_marker { 'voice marker' }
	}
}

// NoLiteral marks the absence of a literal value.
pub struct NoLiteral {}

// Literal is the literal value of a token or AST node.
pub type Literal = NoLiteral | f64 | int | rune | string

// A Token is a result of lexical analysis done by the scanner.
pub struct Token {
pub:
	source_context model.AldaSourceContext
	token_type     TokenType
	text           string
	literal        Literal = NoLiteral{}
	// Only set for note_length tokens.
	denominator f64
	dots        int
	// Only set for repetitions tokens.
	ranges []model.RepetitionRange
}

pub fn (t Token) str() string {
	return '[${t.source_context.line}:${t.source_context.column}] ${t.token_type} | `${t.text}`'
}

struct Scanner {
	filename string
	input    []rune
mut:
	tokens       []Token
	start        int
	current      int
	line         int = 1
	column       int = 1
	start_line   int
	start_column int
	sexp_level   int
}

fn (s &Scanner) error_at(line int, column int, msg string) IError {
	return model.source_errorf(model.AldaSourceContext{
		filename: s.filename
		line:     line
		column:   column
	}, msg)
}

fn (s &Scanner) unexpected_char_error(c rune, context string, line int, column int) IError {
	ctx := if context != '' { ' ' + context } else { '' }
	char_str := match true {
		c == 9 { 'tab' }
		c == 10 { 'newline' }
		c == 13 { 'carriage return' }
		c < 32 || c == 127 { 'control character (${int(c)})' }
		else { "'${c}'" }
	}
	return s.error_at(line, column, 'Unexpected ${char_str}${ctx}')
}

fn (s &Scanner) reached_eof() bool {
	return s.current >= s.input.len
}

fn (s &Scanner) eof_is_next() bool {
	return s.current + 1 >= s.input.len
}

fn (s &Scanner) peek() rune {
	if s.reached_eof() {
		return 0
	}
	return s.input[s.current]
}

fn (s &Scanner) peek_next() rune {
	if s.eof_is_next() {
		return 0
	}
	return s.input[s.current + 1]
}

fn (mut s Scanner) advance() rune {
	r := s.input[s.current]
	s.current++
	if r == `\n` {
		s.line++
		s.column = 1
	} else {
		s.column++
	}
	return r
}

fn (mut s Scanner) match_char(expected rune) bool {
	if s.reached_eof() || s.input[s.current] != expected {
		return false
	}
	s.advance()
	return true
}

fn (mut s Scanner) add(token Token) {
	s.tokens << Token{
		...token
		text:           s.input[s.start..s.current].string()
		source_context: model.AldaSourceContext{
			filename: s.filename
			line:     s.start_line
			column:   s.start_column
		}
	}
}

fn (mut s Scanner) add_token(token_type TokenType, literal Literal) {
	s.add(Token{
		token_type: token_type
		literal:    literal
	})
}

fn (mut s Scanner) skip_comment() {
	for s.peek() != `\n` && !s.reached_eof() {
		s.advance()
	}
}

fn (mut s Scanner) parse_string() ! {
	// NB: The initial quote was already consumed.
	for s.peek() != `"` && !s.reached_eof() {
		s.advance()
	}

	if s.reached_eof() {
		return s.error_at(s.line, s.column, 'Unterminated string')
	}

	// Consume the closing ".
	s.advance()

	s.add_token(.string, s.input[s.start + 1..s.current - 1].string())
}

fn (mut s Scanner) consume_while(pred fn (rune) bool) {
	for !s.reached_eof() && pred(s.peek()) {
		s.advance()
	}
}

fn (mut s Scanner) consume_digits() {
	s.consume_while(is_digit)
}

fn (mut s Scanner) consume_spaces() {
	s.consume_while(fn (c rune) bool {
		return c == ` `
	})
}

fn (s &Scanner) slice(from int) string {
	return s.input[from..s.current].string()
}

fn terminates_note_length(c rune) bool {
	return c in [` `, `\r`, `\n`, `/`, `~`, `]`, `}`]
}

fn (mut s Scanner) parse_note_length() {
	// NB: The first digit was already consumed.
	s.consume_digits()

	// Look for a fractional part.
	if s.peek() == `.` && is_digit(s.peek_next()) {
		s.advance()
		s.consume_digits()
	}

	number := s.slice(s.start).f64()

	c := s.peek()
	n := s.peek_next()
	if c == `s` && (terminates_note_length(n) || s.eof_is_next()) {
		s.advance()
		s.add_token(.note_length_seconds, number)
		return
	}

	if c == `m` && n == `s` {
		s.advance()
		s.advance()
		s.add_token(.note_length_ms, number)
		return
	}

	mut dots := 0
	for s.peek() == `.` {
		dots++
		s.advance()
	}

	s.add(Token{
		token_type:  .note_length
		denominator: number
		dots:        dots
	})
}

fn (mut s Scanner) parse_number() {
	// NB: The initial digit (or minus sign) was already consumed.
	s.consume_digits()
	if s.peek() == `.` && is_digit(s.peek_next()) {
		s.advance()
	}
	s.consume_digits()
	s.add_token(.number, s.slice(s.start).f64())
}

fn (mut s Scanner) parse_repetitions() ! {
	// NB: The initial "'" was already consumed.
	mut ranges := []model.RepetitionRange{}

	for {
		if !is_digit(s.peek()) {
			return s.unexpected_char_error(s.peek(), 'in repetitions', s.line, s.column)
		}

		start_first := s.current
		s.consume_digits()
		first := s.slice(start_first).int()
		mut last := first

		if s.match_char(`-`) {
			if !is_digit(s.peek()) {
				return s.unexpected_char_error(s.peek(), 'in repetitions', s.line, s.column)
			}
			start_last := s.current
			s.consume_digits()
			last = s.slice(start_last).int()
		}

		ranges << model.RepetitionRange{
			first: first
			last:  last
		}

		if !s.match_char(`,`) {
			break
		}
	}

	s.add(Token{
		token_type: .repetitions
		ranges:     ranges
	})
}

fn (mut s Scanner) parse_repeat() ! {
	// NB: The initial '*' was already consumed.
	s.consume_spaces()

	if !is_digit(s.peek()) {
		return s.unexpected_char_error(s.peek(), 'in repeat', s.line, s.column)
	}

	start_digits := s.current
	s.consume_digits()

	c := s.peek()
	if c !in [` `, `\r`, `\n`, `]`, `}`] && !s.reached_eof() {
		return s.unexpected_char_error(c, 'in repeat', s.line, s.column)
	}

	s.add_token(.repeat, s.slice(start_digits).int())
}

fn (mut s Scanner) parse_octave_set() ! {
	// NB: The initial 'o' was already consumed.
	s.consume_digits()

	c := s.peek()
	if c !in [` `, `\r`, `\n`] && !s.reached_eof() {
		return s.unexpected_char_error(c, 'in octave set', s.line, s.column)
	}

	s.add_token(.octave_set, s.input[s.start + 1..s.current].string().int())
}

fn (mut s Scanner) parse_voice_marker() ! {
	// NB: The initial 'V' was already consumed.
	s.consume_digits()

	if s.peek() != `:` {
		return s.unexpected_char_error(s.peek(), 'in voice marker', s.line, s.column)
	}

	s.advance()
	s.add_token(.voice_marker, s.input[s.start + 1..s.current - 1].string().int())
}

fn is_valid_symbol_char(c rune) bool {
	return c !in [` `, `\t`, `\r`, `\n`, `(`, `)`, `[`, `]`, `{`, `}`, `"`]
}

fn is_valid_name_char(c rune) bool {
	return is_letter(c) || is_digit(c) || c in [`_`, `-`, `+`, `'`, `(`, `)`, `.`]
}

fn (mut s Scanner) parse_alias() ! {
	// NB: The initial double quote was already consumed.
	s.consume_while(is_valid_name_char)

	if s.reached_eof() {
		return s.error_at(s.line, s.column, 'Unterminated alias')
	}

	// NB: Alda's scanner constructs (but doesn't return) an error here when the
	// next character isn't a closing quote, so the character is consumed anyway.
	s.advance()

	s.add_token(.alias, s.input[s.start + 1..s.current - 1].string())
}

fn (mut s Scanner) parse_prefixed_name(token_type TokenType, context string) ! {
	// NB: The prefix character was already consumed.
	if !is_valid_name_char(s.peek()) {
		return s.unexpected_char_error(s.peek(), context, s.line, s.column)
	}

	s.consume_while(is_valid_name_char)
	s.add_token(token_type, s.input[s.start + 1..s.current].string())
}

fn is_note_letter(c rune) bool {
	return c >= `a` && c <= `g`
}

fn follows_note_letter(c rune) bool {
	return is_digit(c)
		|| c in [`#`, ` `, `\r`, `\n`, `+`, `-`, `_`, `/`, `~`, `*`, `'`, `}`, `]`, `<`, `>`]
}

fn follows_rest_letter(c rune) bool {
	return is_digit(c) || c in [`#`, ` `, `\r`, `\n`, `/`, `~`, `*`, `'`, `}`, `]`, `<`, `>`]
}

fn (mut s Scanner) scan_token() ! {
	prev_line := s.line
	prev_column := s.column

	c := s.advance()

	match c {
		` `, `\r`, `\n`, `\t` {
			return
		}
		`#` {
			s.skip_comment()
			return
		}
		`(` {
			s.sexp_level++
			s.add_token(.left_paren, NoLiteral{})
			return
		}
		`)` {
			s.sexp_level--
			s.add_token(.right_paren, NoLiteral{})
			return
		}
		else {}
	}

	// Inside of parentheses, we are in "lisp mode," which has different syntax
	// rules.
	if s.sexp_level > 0 {
		if c == `'` {
			s.add_token(.single_quote, NoLiteral{})
		} else if c == `"` {
			s.parse_string()!
		} else if c == `-` || is_digit(c) {
			s.parse_number()
		} else if is_valid_symbol_char(c) {
			s.consume_while(is_valid_symbol_char)
			s.add_token(.symbol, NoLiteral{})
		} else {
			return s.unexpected_char_error(c, 'in S-expression', prev_line, prev_column)
		}
		return
	}

	match c {
		`{` {
			s.add_token(.cram_open, NoLiteral{})
		}
		`}` {
			s.add_token(.cram_close, NoLiteral{})
		}
		`[` {
			s.add_token(.event_seq_open, NoLiteral{})
		}
		`]` {
			s.add_token(.event_seq_close, NoLiteral{})
		}
		`-` {
			s.add_token(.flat, NoLiteral{})
		}
		`+` {
			s.add_token(.sharp, NoLiteral{})
		}
		`_` {
			s.add_token(.natural, NoLiteral{})
		}
		`/` {
			s.add_token(.separator, NoLiteral{})
		}
		`<` {
			s.add_token(.octave_down, NoLiteral{})
		}
		`>` {
			s.add_token(.octave_up, NoLiteral{})
		}
		`:` {
			s.add_token(.colon, NoLiteral{})
		}
		`~` {
			s.add_token(.tie, NoLiteral{})
		}
		`|` {
			s.add_token(.barline, NoLiteral{})
		}
		`=` {
			s.add_token(.equals, NoLiteral{})
		}
		`'` {
			s.parse_repetitions()!
		}
		`*` {
			s.parse_repeat()!
		}
		`"` {
			s.parse_alias()!
		}
		`%` {
			s.parse_prefixed_name(.marker, 'in marker name')!
		}
		`@` {
			s.parse_prefixed_name(.at_marker, 'in marker name')!
		}
		else {
			if is_digit(c) {
				s.parse_note_length()
			} else if is_letter(c) {
				n := s.peek()
				if is_letter(n) {
					s.consume_while(is_valid_name_char)
					s.add_token(.name, NoLiteral{})
				} else if is_note_letter(c) && (follows_note_letter(n) || s.reached_eof()) {
					s.add_token(.note_letter, c)
				} else if c == `r` && (follows_rest_letter(n) || s.reached_eof()) {
					s.add_token(.rest_letter, NoLiteral{})
				} else if c == `o` && (is_digit(n) || s.reached_eof()) {
					s.parse_octave_set()!
				} else if c == `V` && is_digit(n) {
					s.parse_voice_marker()!
				} else {
					return s.unexpected_char_error(n, 'in note/rest/name', s.line, s.column)
				}
			} else {
				return s.unexpected_char_error(c, 'at the top level', prev_line, prev_column)
			}
		}
	}
}

// scan an input string and return a list of tokens. `filename` is included in
// error messages.
pub fn scan(filename string, input string) ![]Token {
	mut s := Scanner{
		filename: filename
		input:    input.runes()
	}

	for !s.reached_eof() {
		s.start = s.current
		s.start_line = s.line
		s.start_column = s.column
		s.scan_token()!
	}

	s.tokens << Token{
		token_type:     .eof
		source_context: model.AldaSourceContext{
			filename: s.filename
			line:     s.line
			column:   s.column
		}
	}

	return s.tokens
}

// scan_file reads a file, scans it, and returns a list of tokens.
pub fn scan_file(filepath string) ![]Token {
	return scan(filepath, os.read_file(filepath)!)
}
