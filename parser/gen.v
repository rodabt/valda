module parser

import model

// Generating AST nodes from score updates: the inverse of ASTNode.updates()
// (minus source context). Used by the MusicXML importer.

fn with_duration(node ASTNode, d model.Duration) !ASTNode {
	if d.components.len == 0 {
		return node
	}

	mut dnode := ASTNode{
		node_type: .duration_node
	}

	for component in d.components {
		match component {
			model.Barline {
				dnode.children << ASTNode{
					node_type: .barline_node
				}
			}
			model.NoteLength {
				mut nl := ASTNode{
					node_type: .note_length_node
					children:  [
						ASTNode{
							node_type: .denominator_node
							literal:   component.denominator
						},
					]
				}
				if component.dots > 0 {
					nl.children << ASTNode{
						node_type: .dots_node
						literal:   component.dots
					}
				}
				dnode.children << nl
			}
			model.NoteLengthMs {
				dnode.children << ASTNode{
					node_type: .note_length_ms_node
					literal:   component.quantity
				}
			}
			model.NoteLengthSeconds {
				dnode.children << ASTNode{
					node_type: .note_length_seconds_node
					literal:   component.quantity
				}
			}
			else {
				return error('unexpected DurationComponent during AST generation: ${component.type_name()}')
			}
		}
	}

	mut result := node
	result.children << dnode
	return result
}

fn lisp_form_to_node(form model.LispForm) !ASTNode {
	match form {
		model.LispList {
			mut node := ASTNode{
				node_type: .lisp_list_node
			}
			for element in form.elements {
				node.children << lisp_form_to_node(element)!
			}
			return node
		}
		model.LispNumber {
			return ASTNode{
				node_type: .lisp_number_node
				literal:   form.value
			}
		}
		model.LispQuotedForm {
			return ASTNode{
				node_type: .lisp_quoted_form_node
				children:  [lisp_form_to_node(form.form)!]
			}
		}
		model.LispString {
			return ASTNode{
				node_type: .lisp_string_node
				literal:   form.value
			}
		}
		model.LispSymbol {
			return ASTNode{
				node_type: .lisp_symbol_node
				literal:   form.name
			}
		}
		else {
			return error('unexpected LispForm type during AST gen: ${form.type_name()}')
		}
	}
}

fn lisp_call(symbol string, args ...ASTNode) ASTNode {
	mut children := [ASTNode{
		node_type: .lisp_symbol_node
		literal:   symbol
	}]
	children << args
	return ASTNode{
		node_type: .lisp_list_node
		children:  children
	}
}

// map_isolated_update maps a single score update to an AST node. Parts and
// voices are handled upstream.
fn map_isolated_update(update model.ScoreUpdate) !ASTNode {
	match update {
		model.AtMarker {
			return ASTNode{
				node_type: .at_marker_node
				literal:   update.name
			}
		}
		model.AttributeUpdate {
			pu := update.part_update
			match pu {
				model.OctaveSet {
					return ASTNode{
						node_type: .octave_set_node
						literal:   pu.octave_number
					}
				}
				model.OctaveUp {
					return ASTNode{
						node_type: .octave_up_node
					}
				}
				model.OctaveDown {
					return ASTNode{
						node_type: .octave_down_node
					}
				}
				// Other attributes are generated as Lisp. As in Alda, only the subset
				// that the MusicXML importer generates is handled.
				model.DynamicMarking {
					return lisp_call(pu.marking)
				}
				model.KeySignatureSet {
					return lisp_call('key-signature', ASTNode{
						node_type: .lisp_string_node
						literal:   pu.key_signature.str()
					})
				}
				model.TranspositionSet {
					return lisp_call('transpose', ASTNode{
						node_type: .lisp_number_node
						literal:   pu.semitones
					})
				}
				else {
					return error('unexpected PartUpdate type during AST generation: ${pu.type_name()}')
				}
			}
		}
		model.Barline {
			return ASTNode{
				node_type: .barline_node
			}
		}
		model.Chord {
			return ASTNode{
				node_type: .chord_node
				children:  map_inner_events(update.events)!
			}
		}
		model.Cram {
			cram := ASTNode{
				node_type: .cram_node
				children:  [
					ASTNode{
						node_type: .event_sequence_node
						children:  map_inner_events(update.events)!
					},
				]
			}
			return with_duration(cram, update.duration)
		}
		model.EventSequence {
			return ASTNode{
				node_type: .event_sequence_node
				children:  map_inner_events(update.events)!
			}
		}
		model.LispList {
			return lisp_form_to_node(update)
		}
		model.Marker {
			return ASTNode{
				node_type: .marker_node
				literal:   update.name
			}
		}
		model.Note {
			pitch := update.pitch
			if pitch !is model.LetterAndAccidentals {
				return error('unexpected PitchIdentifier type during AST gen: ${pitch.type_name()}')
			}
			laa := pitch as model.LetterAndAccidentals

			mut laa_node := ASTNode{
				node_type: .note_letter_and_accidentals_node
				children:  [
					ASTNode{
						node_type: .note_letter_node
						literal:   rune(`a` + int(laa.note_letter))
					},
				]
			}

			if laa.accidentals.len > 0 {
				laa_node.children << ASTNode{
					node_type: .note_accidentals_node
					children:  laa.accidentals.map(match it {
						.flat {
							ASTNode{
								node_type: .flat_node
							}
						}
						.natural {
							ASTNode{
								node_type: .natural_node
							}
						}
						.sharp {
							ASTNode{
								node_type: .sharp_node
							}
						}
					})
				}
			}

			mut note := with_duration(ASTNode{
				node_type: .note_node
				children:  [laa_node]
			}, update.duration)!

			if update.slurred {
				note.children << ASTNode{
					node_type: .tie_node
				}
			}

			return note
		}
		model.OnRepetitions {
			node := map_isolated_update(update.event)!
			mut reps := ASTNode{
				node_type: .repetitions_node
			}
			for r in update.repetitions {
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
			return ASTNode{
				node_type: .on_repetitions_node
				children:  [node, reps]
			}
		}
		model.Repeat {
			return ASTNode{
				node_type: .repeat_node
				children:  [map_isolated_update(update.event)!,
					ASTNode{
						node_type: .times_node
						literal:   update.times
					}]
			}
		}
		model.Rest {
			return with_duration(ASTNode{
				node_type: .rest_node
			}, update.duration)
		}
		model.VariableDefinition {
			return ASTNode{
				node_type: .variable_definition_node
				children:  [
					ASTNode{
						node_type: .variable_name_node
						literal:   update.variable_name
					},
					ASTNode{
						node_type: .event_sequence_node
						children:  map_inner_events(update.events)!
					},
				]
			}
		}
		model.VariableReference {
			return ASTNode{
				node_type: .variable_reference_node
				literal:   update.variable_name
			}
		}
		else {
			return error('unexpected ScoreUpdate type during AST gen: ${update.type_name()}')
		}
	}
}

// map_inner_events maps a group of inner updates to AST nodes. Voice markers
// start (or continue) a voice group; subsequent nodes go into the voice.
fn map_inner_events(updates []model.ScoreUpdate) ![]ASTNode {
	mut top := []ASTNode{}
	mut group := ASTNode{
		node_type: .voice_group_node
	}
	mut in_group := false

	for update in updates {
		match update {
			model.VoiceMarker {
				in_group = true
				group.children << ASTNode{
					node_type: .voice_node
					children:  [
						ASTNode{
							node_type: .voice_number_node
							literal:   update.voice_number
						},
						ASTNode{
							node_type: .event_sequence_node
						},
					]
				}
			}
			model.VoiceGroupEndMarker {
				group.children << ASTNode{
					node_type: .voice_group_end_marker_node
				}
				top << group
				group = ASTNode{
					node_type: .voice_group_node
				}
				in_group = false
			}
			else {
				node := map_isolated_update(update)!
				if in_group {
					group.children[group.children.len - 1].children[1].children << node
				} else {
					top << node
				}
			}
		}
	}

	if in_group {
		top << group
	}

	return top
}

// generate_ast generates a root AST node from score updates.
pub fn generate_ast(updates []model.ScoreUpdate) !ASTNode {
	mut root := ASTNode{
		node_type: .root_node
	}

	// Construct part nodes by iterating backwards.
	mut part_end := updates.len
	mut parts := []ASTNode{}
	for i := updates.len - 1; i >= 0; i-- {
		decl := updates[i]
		if decl is model.PartDeclaration {
			mut decl_node := ASTNode{
				node_type: .part_declaration_node
				children:  [
					ASTNode{
						node_type: .part_names_node
						children:  decl.names.map(ASTNode{
							node_type: .part_name_node
							literal:   it
						})
					},
				]
			}
			if decl.alias.len > 0 {
				decl_node.children << ASTNode{
					node_type: .part_alias_node
					literal:   decl.alias
				}
			}

			parts.prepend(ASTNode{
				node_type: .part_node
				children:  [decl_node, ASTNode{
					node_type: .event_sequence_node
					children:  map_inner_events(updates[i + 1..part_end])!
				}]
			})
			part_end = i
		}
	}

	// Any remaining prefix goes into an implicit part.
	if part_end > 0 {
		root.children << ASTNode{
			node_type: .implicit_part_node
			children:  [
				ASTNode{
					node_type: .event_sequence_node
					children:  map_inner_events(updates[..part_end])!
				},
			]
		}
	}

	root.children << parts
	return root
}
