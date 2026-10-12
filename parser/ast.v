module parser

import math
import strings
import x.json2
import model

// A NodeType is a type of AST node output by the parser.
pub enum NodeType {
	at_marker_node
	barline_node
	chord_node
	cram_node
	denominator_node
	dots_node
	duration_node
	event_sequence_node
	first_repetition_node
	flat_node
	implicit_part_node
	last_repetition_node
	lisp_list_node
	lisp_number_node
	lisp_quoted_form_node
	lisp_string_node
	lisp_symbol_node
	marker_node
	natural_node
	note_accidentals_node
	note_length_ms_node
	note_length_node
	note_length_seconds_node
	note_letter_and_accidentals_node
	note_letter_node
	note_node
	octave_down_node
	octave_set_node
	octave_up_node
	on_repetitions_node
	part_alias_node
	part_declaration_node
	part_name_node
	part_names_node
	part_node
	repeat_node
	repetition_range_node
	repetitions_node
	rest_node
	root_node
	sharp_node
	tie_node
	times_node
	variable_definition_node
	variable_name_node
	variable_reference_node
	voice_node
	voice_group_end_marker_node
	voice_group_node
	voice_number_node
}

// str returns the Alda (Go client) name of the node type, e.g. "NoteNode".
pub fn (nt NodeType) str() string {
	return node_type_names[int(nt)]
}

const node_type_names = ['AtMarkerNode', 'BarlineNode', 'ChordNode', 'CramNode', 'DenominatorNode',
	'DotsNode', 'DurationNode', 'EventSequenceNode', 'FirstRepetitionNode', 'FlatNode',
	'ImplicitPartNode', 'LastRepetitionNode', 'LispListNode', 'LispNumberNode', 'LispQuotedFormNode',
	'LispStringNode', 'LispSymbolNode', 'MarkerNode', 'NaturalNode', 'NoteAccidentalsNode',
	'NoteLengthMsNode', 'NoteLengthNode', 'NoteLengthSecondsNode', 'NoteLetterAndAccidentalsNode',
	'NoteLetterNode', 'NoteNode', 'OctaveDownNode', 'OctaveSetNode', 'OctaveUpNode',
	'OnRepetitionsNode', 'PartAliasNode', 'PartDeclarationNode', 'PartNameNode', 'PartNamesNode',
	'PartNode', 'RepeatNode', 'RepetitionRangeNode', 'RepetitionsNode', 'RestNode', 'RootNode',
	'SharpNode', 'TieNode', 'TimesNode', 'VariableDefinitionNode', 'VariableNameNode',
	'VariableReferenceNode', 'VoiceNode', 'VoiceGroupEndMarkerNode', 'VoiceGroupNode',
	'VoiceNumberNode']

pub struct ASTNode {
pub mut:
	node_type      NodeType
	literal        Literal = NoLiteral{}
	children       []ASTNode
	source_context model.AldaSourceContext
}

fn (node ASTNode) lit_f64() f64 {
	return match node.literal {
		f64 { node.literal }
		int { f64(node.literal) }
		else { 0.0 }
	}
}

fn (node ASTNode) lit_int() int {
	return match node.literal {
		int { node.literal }
		f64 { int(node.literal) }
		else { 0 }
	}
}

fn (node ASTNode) lit_str() string {
	return match node.literal {
		string { node.literal }
		else { '' }
	}
}

// fmt_number formats a number the way Go's %v does for float64: integers
// without a decimal point, otherwise the shortest representation.
pub fn fmt_number(x f64) string {
	if x == math.trunc(x) && math.abs(x) < 1e15 {
		return i64(x).str()
	}
	return x.str()
}

fn literal_json(node ASTNode) ?json2.Any {
	return match node.literal {
		NoLiteral { none }
		f64 { json2.Any(node.literal) }
		int { json2.Any(node.literal) }
		rune { json2.Any(utf32_to_str(u32(node.literal))) }
		string { json2.Any(node.literal) }
	}
}

// json returns a JSON representation of an ASTNode.
pub fn (node ASTNode) json() json2.Any {
	mut m := map[string]json2.Any{}
	m['type'] = node.node_type.str()

	if node.children.len > 0 {
		m['children'] = json2.Any(node.children.map(it.json()))
	}

	if lit := literal_json(node) {
		m['literal'] = lit
	}

	if node.source_context.line > 0 {
		mut sc := map[string]json2.Any{}
		sc['line'] = node.source_context.line
		sc['column'] = node.source_context.column
		m['source-context'] = json2.Any(sc)
	}

	return json2.Any(m)
}

// human_readable returns a human-readable textual representation of an AST.
pub fn (node ASTNode) human_readable() string {
	mut sb := strings.new_builder(1024)
	write_human(node, 0, mut sb)
	return sb.str().trim_right('\n')
}

fn write_human(node ASTNode, indent int, mut sb strings.Builder) {
	sb.write_string('  '.repeat(indent))
	sb.write_string(node.node_type.str())
	if node.source_context.line > 0 {
		sb.write_string(' [${node.source_context.line}:${node.source_context.column}]')
	}
	match node.literal {
		NoLiteral {}
		f64 { sb.write_string(': ${fmt_number(node.literal)}') }
		int { sb.write_string(': ${node.literal}') }
		rune { sb.write_string(': "${utf32_to_str(u32(node.literal))}"') }
		string { sb.write_string(': "${node.literal}"') }
	}
	sb.write_string('\n')
	for child in node.children {
		write_human(child, indent + 1, mut sb)
	}
}

fn (node ASTNode) expect_children() ! {
	if node.children.len == 0 {
		return error('${node.node_type} has no children')
	}
}

fn (node ASTNode) expect_n_children(expected ...int) ! {
	if node.children.len !in expected {
		return error('expected ${node.node_type} to have ${expected} children, but it has ${node.children.len}')
	}
}

fn (node ASTNode) expect_type(expected NodeType) !ASTNode {
	if node.node_type != expected {
		return error('expected ${expected} node, but got ${node.node_type} node')
	}
	return node
}

fn err_unexpected_child(parent NodeType, child NodeType) IError {
	return error('unexpected ${parent} child: ${child}')
}

fn duration(node ASTNode) !model.Duration {
	mut d := model.Duration{}

	for component in node.children {
		match component.node_type {
			.barline_node {
				d.components << model.Barline{
					source_context: component.source_context
				}
			}
			.note_length_node {
				component.expect_children()!
				denom := component.children[0].expect_type(.denominator_node)!
				mut dots := 0
				if component.children.len > 1 {
					dots = component.children[1].expect_type(.dots_node)!.lit_int()
				}
				d.components << model.NoteLength{
					denominator: denom.lit_f64()
					dots:        dots
				}
			}
			.note_length_ms_node {
				d.components << model.NoteLengthMs{
					quantity: component.lit_f64()
				}
			}
			.note_length_seconds_node {
				d.components << model.NoteLengthSeconds{
					quantity: component.lit_f64()
				}
			}
			else {
				return err_unexpected_child(node.node_type, component.node_type)
			}
		}
	}

	return d
}

fn concat_child_updates(node ASTNode) ![]model.ScoreUpdate {
	mut updates := []model.ScoreUpdate{}
	for child in node.children {
		updates << child.updates()!
	}
	return updates
}

fn lisp_form(node ASTNode) !model.LispForm {
	match node.node_type {
		.lisp_list_node {
			mut elements := []model.LispForm{}
			for child in node.children {
				elements << lisp_form(child)!
			}
			return model.LispList{
				source_context: node.source_context
				elements:       elements
			}
		}
		.lisp_number_node {
			return model.LispNumber{
				source_context: node.source_context
				value:          node.lit_f64()
			}
		}
		.lisp_quoted_form_node {
			node.expect_n_children(1)!
			return model.LispQuotedForm{
				source_context: node.source_context
				form:           lisp_form(node.children[0])!
			}
		}
		.lisp_string_node {
			return model.LispString{
				source_context: node.source_context
				value:          node.lit_str()
			}
		}
		.lisp_symbol_node {
			return model.LispSymbol{
				source_context: node.source_context
				name:           node.lit_str()
			}
		}
		else {
			return error('unexpected ${node.node_type} node inside of Lisp form')
		}
	}
}

fn single_event(updates []model.ScoreUpdate, context model.AldaSourceContext) model.ScoreUpdate {
	if updates.len == 1 {
		return updates[0]
	}
	return model.EventSequence{
		source_context: context
		events:         updates
	}
}

// updates converts an AST node into the score updates it represents.
pub fn (node ASTNode) updates() ![]model.ScoreUpdate {
	match node.node_type {
		.at_marker_node {
			return [
				model.ScoreUpdate(model.AtMarker{
					source_context: node.source_context
					name:           node.lit_str()
				}),
			]
		}
		.barline_node {
			return [
				model.ScoreUpdate(model.Barline{
					source_context: node.source_context
				}),
			]
		}
		.chord_node {
			node.expect_children()!
			return [
				model.ScoreUpdate(model.Chord{
					source_context: node.source_context
					events:         concat_child_updates(node)!
				}),
			]
		}
		.cram_node {
			node.expect_n_children(1, 2)!
			events_node := node.children[0].expect_type(.event_sequence_node)!
			mut d := model.Duration{}
			if node.children.len > 1 {
				d = duration(node.children[1].expect_type(.duration_node)!)!
			}
			return [
				model.ScoreUpdate(model.Cram{
					source_context: node.source_context
					events:         concat_child_updates(events_node)!
					duration:       d
				}),
			]
		}
		.event_sequence_node {
			return [
				model.ScoreUpdate(model.EventSequence{
					source_context: node.source_context
					events:         concat_child_updates(node)!
				}),
			]
		}
		.implicit_part_node {
			node.expect_n_children(1)!
			return concat_child_updates(node.children[0].expect_type(.event_sequence_node)!)
		}
		.lisp_list_node {
			form := lisp_form(node)!
			return [model.ScoreUpdate(form as model.LispList)]
		}
		.marker_node {
			return [
				model.ScoreUpdate(model.Marker{
					source_context: node.source_context
					name:           node.lit_str()
				}),
			]
		}
		.note_node {
			node.expect_children()!
			laa_node := node.children[0].expect_type(.note_letter_and_accidentals_node)!
			letter_node := laa_node.children[0].expect_type(.note_letter_node)!
			letter_rune := match letter_node.literal {
				rune { letter_node.literal }
				else { rune(0) }
			}

			mut laa := model.LetterAndAccidentals{
				note_letter: model.new_note_letter(letter_rune)!
			}

			if laa_node.children.len > 1 {
				accidentals_node := laa_node.children[1].expect_type(.note_accidentals_node)!
				laa.has_accidentals = true
				for child in accidentals_node.children {
					match child.node_type {
						.flat_node {
							laa.accidentals << .flat
						}
						.natural_node {
							laa.accidentals << .natural
						}
						.sharp_node {
							laa.accidentals << .sharp
						}
						else {
							return err_unexpected_child(accidentals_node.node_type, child.node_type)
						}
					}
				}
			}

			mut note := model.Note{
				source_context: node.source_context
				pitch:          laa
			}

			for child in node.children[1..] {
				match child.node_type {
					.duration_node { note.duration = duration(child)! }
					.tie_node { note.slurred = true }
					else { return err_unexpected_child(node.node_type, child.node_type) }
				}
			}

			return [model.ScoreUpdate(note)]
		}
		.octave_down_node {
			return [
				model.ScoreUpdate(model.AttributeUpdate{
					source_context: node.source_context
					part_update:    model.OctaveDown{}
				}),
			]
		}
		.octave_set_node {
			return [
				model.ScoreUpdate(model.AttributeUpdate{
					source_context: node.source_context
					part_update:    model.OctaveSet{
						octave_number: node.lit_int()
					}
				}),
			]
		}
		.octave_up_node {
			return [
				model.ScoreUpdate(model.AttributeUpdate{
					source_context: node.source_context
					part_update:    model.OctaveUp{}
				}),
			]
		}
		.on_repetitions_node {
			node.expect_n_children(2)!
			event_node := node.children[0]
			event := single_event(event_node.updates()!, event_node.source_context)

			repetitions := node.children[1].expect_type(.repetitions_node)!
			repetitions.expect_children()!

			mut ranges := []model.RepetitionRange{}
			for rr in repetitions.children {
				rr.expect_n_children(2)!
				first := rr.children[0].expect_type(.first_repetition_node)!
				last := rr.children[1].expect_type(.last_repetition_node)!
				ranges << model.RepetitionRange{
					first: first.lit_int()
					last:  last.lit_int()
				}
			}

			return [
				model.ScoreUpdate(model.OnRepetitions{
					source_context: node.source_context
					event:          event
					repetitions:    ranges
				}),
			]
		}
		.part_node {
			node.expect_n_children(2)!
			decl_node := node.children[0].expect_type(.part_declaration_node)!
			names_node := decl_node.children[0].expect_type(.part_names_node)!
			names_node.expect_children()!

			mut names := []string{}
			for child in names_node.children {
				names << child.expect_type(.part_name_node)!.lit_str()
			}

			mut alias := ''
			if decl_node.children.len > 1 {
				alias = decl_node.children[1].expect_type(.part_alias_node)!.lit_str()
			}

			events := node.children[1].expect_type(.event_sequence_node)!

			mut result := [
				model.ScoreUpdate(model.PartDeclaration{
					source_context: node.source_context
					names:          names
					alias:          alias
				}),
			]
			result << concat_child_updates(events)!
			return result
		}
		.repeat_node {
			node.expect_n_children(2)!
			event_node := node.children[0]
			times := node.children[1].expect_type(.times_node)!
			return [
				model.ScoreUpdate(model.Repeat{
					source_context: event_node.source_context
					event:          single_event(event_node.updates()!, event_node.source_context)
					times:          times.lit_int()
				}),
			]
		}
		.rest_node {
			mut d := model.Duration{}
			match node.children.len {
				0 {}
				1 {
					d = duration(node.children[0].expect_type(.duration_node)!)!
				}
				else {
					return error('rest node must have either 0 or 1 children')
				}
			}
			return [
				model.ScoreUpdate(model.Rest{
					source_context: node.source_context
					duration:       d
				}),
			]
		}
		.root_node, .voice_group_node {
			return concat_child_updates(node)
		}
		.variable_definition_node {
			node.expect_n_children(2)!
			name := node.children[0].expect_type(.variable_name_node)!
			events := node.children[1].expect_type(.event_sequence_node)!
			return [
				model.ScoreUpdate(model.VariableDefinition{
					source_context: node.source_context
					variable_name:  name.lit_str()
					events:         concat_child_updates(events)!
				}),
			]
		}
		.variable_reference_node {
			return [
				model.ScoreUpdate(model.VariableReference{
					source_context: node.source_context
					variable_name:  node.lit_str()
				}),
			]
		}
		.voice_group_end_marker_node {
			return [
				model.ScoreUpdate(model.VoiceGroupEndMarker{
					source_context: node.source_context
				}),
			]
		}
		.voice_node {
			node.expect_n_children(2)!
			number := node.children[0].expect_type(.voice_number_node)!
			events := node.children[1].expect_type(.event_sequence_node)!
			mut result := [
				model.ScoreUpdate(model.VoiceMarker{
					source_context: number.source_context
					voice_number:   number.lit_int()
				}),
			]
			result << concat_child_updates(events)!
			return result
		}
		else {
			return error("updates() not implemented for AST node type '${node.node_type}'")
		}
	}
}
