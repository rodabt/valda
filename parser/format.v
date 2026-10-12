module parser

import strings

// Formatting AST nodes back into Alda source code. Comments are not retained
// (as in Alda, they're dropped during parsing).

enum VarDefState {
	none_     // not currently in a var def
	defining  // currently formatting a var def (cannot go to a new line)
	last_node // last node of a var def, treated specially
}

@[params]
pub struct FormatOptions {
pub:
	// Line length at which to soft-wrap formatted output.
	soft_wrap_len int = 80
	// Indent text (e.g. spaces vs. tabs).
	indent_text string = '  '
}

struct Formatter {
	soft_wrap_len int
	indent_text   string
mut:
	var_def      VarDefState
	indent_level int
	texts        []string
	out          strings.Builder
}

// line constructs the current line being formatted.
fn (f &Formatter) line() string {
	text := f.texts.join(' ')
	if text.len == 0 {
		return text
	}
	return f.indent_text.repeat(f.indent_level) + text
}

fn (mut f Formatter) empty_line() {
	if f.var_def == .none_ {
		f.flush()
		f.out.write_string('\n')
	}
}

fn (mut f Formatter) flush() {
	if f.texts.len > 0 && f.var_def == .none_ {
		f.out.write_string(f.line() + '\n')
		f.texts = []
	}
}

fn (mut f Formatter) indent() {
	if f.var_def == .last_node {
		// During the last node of a var def, we may exit the var def and continue
		// on the next line.
		f.var_def = .none_
	}
	if f.var_def == .none_ {
		f.flush()
		f.indent_level++
	}
}

fn (mut f Formatter) unindent() {
	if f.var_def == .none_ {
		f.flush()
		f.indent_level--
	}
}

// write adds an unwrappable token, wrapping before it if the line gets too
// long.
fn (mut f Formatter) write(text string) {
	f.texts << text
	if f.line().len > f.soft_wrap_len && f.var_def == .none_ {
		f.texts.delete_last()
		f.flush()
		f.texts << text
	}
}

fn fmt_float(x f64) string {
	return fmt_number(x)
}

fn (mut f Formatter) format_with_duration(pre string, d ASTNode, post string) ! {
	mut text := pre
	mut should_tie := false

	for i, child in d.children {
		match child.node_type {
			.barline_node {
				if i == d.children.len - 1 {
					// A final barline: write the post text before it for clarity.
					text += post
				}
				if text.len > 0 {
					f.write(text)
				}
				f.write('|')
				text = ''
			}
			.note_length_node {
				if should_tie {
					text += '~'
				}
				child.expect_n_children(1, 2)!
				denom := child.children[0].expect_type(.denominator_node)!
				mut dots := 0
				if child.children.len > 1 {
					dots = child.children[1].expect_type(.dots_node)!.lit_int()
				}
				text += fmt_float(denom.lit_f64()) + '.'.repeat(dots)
				should_tie = true
			}
			.note_length_ms_node {
				if should_tie {
					text += '~'
				}
				text += fmt_float(child.lit_f64()) + 'ms'
				should_tie = true
			}
			.note_length_seconds_node {
				if should_tie {
					text += '~'
				}
				text += fmt_float(child.lit_f64()) + 's'
				should_tie = true
			}
			else {
				return error('unexpected DurationNode ${child.node_type} during formatting')
			}
		}
	}

	if text.len > 0 {
		f.write(text + post)
	}
}

fn lisp_string(node ASTNode) !string {
	return match node.node_type {
		.lisp_list_node {
			mut texts := []string{}
			for child in node.children {
				texts << lisp_string(child)!
			}
			'(${texts.join(' ')})'
		}
		.lisp_number_node {
			match node.literal {
				int { node.literal.str() }
				else { fmt_float(node.lit_f64()) }
			}
		}
		.lisp_quoted_form_node {
			"'" + lisp_string(node.children[0])!
		}
		.lisp_string_node {
			'"${node.lit_str()}"'
		}
		.lisp_symbol_node {
			node.lit_str()
		}
		else {
			error('unexpected LispListNode ${node.node_type} during formatting')
		}
	}
}

fn (mut f Formatter) format_inner_events(nodes ...ASTNode) ! {
	for node in nodes {
		match node.node_type {
			.at_marker_node {
				f.write('@${node.lit_str()}')
			}
			.barline_node {
				f.write('|')
			}
			.chord_node {
				node.expect_children()!
				// Nodes between notes are formatted after the separator, since they
				// apply to the subsequent note.
				mut last_note_or_rest := 0
				for i, child in node.children {
					if child.node_type in [.note_node, .rest_node] {
						last_note_or_rest = i
					}
				}
				for i, child in node.children {
					f.format_inner_events(child)!
					if child.node_type in [.note_node, .rest_node] && i < last_note_or_rest {
						f.write('/')
					}
				}
			}
			.cram_node {
				node.expect_n_children(1, 2)!
				events := node.children[0].expect_type(.event_sequence_node)!
				f.write('{')
				f.format_inner_events(...events.children)!
				if node.children.len > 1 {
					f.format_with_duration('}', node.children[1].expect_type(.duration_node)!,
						'')!
				} else {
					f.write('}')
				}
			}
			.event_sequence_node {
				f.flush()
				f.write('[')
				f.indent()
				f.format_inner_events(...node.children)!
				f.unindent()
				f.write(']')
			}
			.lisp_list_node {
				// Lisp lists are generally short; written as a single token.
				f.write(lisp_string(node)!)
			}
			.marker_node {
				f.write('%${node.lit_str()}')
			}
			.note_node {
				node.expect_n_children(1, 2, 3)!
				laa := node.children[0].expect_type(.note_letter_and_accidentals_node)!
				laa.expect_children()!
				letter := laa.children[0].expect_type(.note_letter_node)!
				mut pitch := match letter.literal {
					rune { utf32_to_str(u32(letter.literal)) }
					else { '' }
				}

				if laa.children.len > 1 {
					accidentals := laa.children[1].expect_type(.note_accidentals_node)!
					for child in accidentals.children {
						pitch += match child.node_type {
							.flat_node { '-' }
							.natural_node { '_' }
							.sharp_node { '+' }
							else { return error('unexpected NoteAccidentalsNode ${child.node_type} during formatting') }
						}
					}
				}

				mut slur := ''
				for child in node.children[1..] {
					if child.node_type == .tie_node {
						slur = '~'
					}
				}

				if node.children.len > 1 && node.children[1].node_type == .duration_node {
					f.format_with_duration(pitch, node.children[1], slur)!
				} else {
					f.write(pitch + slur)
				}
			}
			.octave_down_node {
				f.write('<')
			}
			.octave_set_node {
				f.write('o${node.lit_int()}')
			}
			.octave_up_node {
				f.write('>')
			}
			.repeat_node {
				node.expect_n_children(2)!
				f.format_inner_events(node.children[0])!
				times := node.children[1].expect_type(.times_node)!
				f.write('*${times.lit_int()}')
			}
			.on_repetitions_node {
				node.expect_n_children(2)!
				f.format_inner_events(node.children[0])!
				repetitions := node.children[1].expect_type(.repetitions_node)!
				mut ranges := []string{}
				for child in repetitions.children {
					rr := child.expect_type(.repetition_range_node)!
					rr.expect_n_children(2)!
					first := rr.children[0].expect_type(.first_repetition_node)!.lit_int()
					last := rr.children[1].expect_type(.last_repetition_node)!.lit_int()
					ranges << if first == last { '${first}' } else { '${first}-${last}' }
				}
				f.write("'" + ranges.join(','))
			}
			.rest_node {
				if node.children.len > 0 {
					f.format_with_duration('r', node.children[0].expect_type(.duration_node)!,
						'')!
				} else {
					f.write('r')
				}
			}
			.variable_definition_node {
				// Formatted text must stay on the same line as the variable name,
				// except that the last node may continue on new lines (e.g. an event
				// sequence or voice group).
				f.flush()
				f.var_def = .defining
				node.expect_n_children(2)!
				name := node.children[0].expect_type(.variable_name_node)!
				f.write('${name.lit_str()} =')
				events := node.children[1].expect_type(.event_sequence_node)!
				if events.children.len > 0 {
					last := events.children.len - 1
					f.format_inner_events(...events.children[..last])!
					f.var_def = .last_node
					f.format_inner_events(events.children[last])!
				}
				f.var_def = .none_
				f.flush()
			}
			.variable_reference_node {
				f.write(node.lit_str())
			}
			.voice_group_end_marker_node {
				f.write('V0:')
			}
			.voice_group_node {
				f.flush()
				f.format_inner_events(...node.children)!
			}
			.voice_node {
				node.expect_n_children(2)!
				number := node.children[0].expect_type(.voice_number_node)!
				f.write('V${number.lit_int()}:')
				f.indent()
				events := node.children[1].expect_type(.event_sequence_node)!
				f.format_inner_events(...events.children)!
				f.unindent()
			}
			else {
				return error('unexpected ASTNode type ${node.node_type} during formatting')
			}
		}
	}
}

fn (mut f Formatter) format_top_level(root ASTNode) ! {
	for i, part in root.children {
		match part.node_type {
			.implicit_part_node {
				part.expect_n_children(1)!
				events := part.children[0].expect_type(.event_sequence_node)!
				f.format_inner_events(...events.children)!
			}
			.part_node {
				part.expect_n_children(2)!
				decl := part.children[0].expect_type(.part_declaration_node)!
				decl.expect_n_children(1, 2)!
				names_node := decl.children[0].expect_type(.part_names_node)!
				names_node.expect_children()!

				mut names := []string{}
				for child in names_node.children {
					names << child.expect_type(.part_name_node)!.lit_str()
				}

				if decl.children.len > 1 {
					alias := decl.children[1].expect_type(.part_alias_node)!
					f.write('${names.join('/')} "${alias.lit_str()}":')
				} else {
					f.write('${names.join('/')}:')
				}

				f.indent()
				events := part.children[1].expect_type(.event_sequence_node)!
				f.format_inner_events(...events.children)!
				f.unindent()
			}
			else {}
		}

		f.flush()
		if i + 1 < root.children.len {
			f.empty_line()
		}
	}
}

// format_ast performs rudimentary formatting of Alda code: spacing,
// indentation, and line wrapping.
pub fn format_ast(root ASTNode, opts FormatOptions) !string {
	mut f := Formatter{
		soft_wrap_len: opts.soft_wrap_len
		indent_text:   opts.indent_text
		out:           strings.new_builder(4096)
	}
	f.format_top_level(root)!
	return f.out.str()
}
