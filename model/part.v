module model

// A PartDeclaration sets the current instruments of the score, creating them if
// necessary.
pub struct PartDeclaration {
pub:
	source_context AldaSourceContext
	names          []string
	alias          string
}

// A Part is a single instance of an instrument used within a score.
@[heap]
pub struct Part {
pub mut:
	id               string
	name             string
	stock_instrument MidiInstrument
	tempo_role       TempoRole
	tempo            f64
	key_signature    KeySignature
	transposition    int
	reference_pitch  f64
	current_offset   f64
	last_offset      f64
	octave           int
	volume           f64
	track_volume     f64
	panning          f64
	// The MIDI channel number (0-15) that this part is currently assigned to.
	// -1 means that no channel has been assigned yet.
	midi_channel int
	// When true, the score declares a specific MIDI channel for this part via
	// the `midi-channel` attribute.
	has_explicit_midi_channel bool
	quantization              f64
	duration                  Duration
	time_scale                f64
	// Offset => tempo value applied at that offset. See record_tempo_value.
	tempo_values map[f64]f64
	// Tracks the case where a part overrides a global attribute change with a
	// local attribute change at the exact same offset.
	local_attribute_override ?PartUpdate
	// How many times through a repeated sequence the part has played so far.
	current_repetition int
	// A snapshot of the part at the start of a voice group, used as a template
	// for each new voice.
	voice_template &Part = unsafe { nil }
	// Clones (voices) retain a reference to the original part.
	origin &Part = unsafe { nil }
	// The clones created, one per voice. Shared between a part and its clones.
	voices &Voices = unsafe { nil }
	// The score to which the part belongs.
	score &Score = unsafe { nil }
}

// record_tempo_value records an entry in the part's history of tempo values,
// so that tempo changes can be included in exported MIDI sequences.
pub fn (mut part Part) record_tempo_value() {
	part.tempo_values[part.current_offset] = part.tempo
}

// clone returns a copy of a part. Mirrors Alda's deepcopy semantics: public
// state is copied deeply, while the voice bookkeeping references are shared.
pub fn (part &Part) clone() &Part {
	mut c := &Part{
		...*part
	}
	c.key_signature = part.key_signature.clone()
	c.duration = part.duration.clone()
	c.tempo_values = part.tempo_values.clone()
	c.local_attribute_override = none
	return c
}

// new_part returns a new part in the score.
pub fn (mut score Score) new_part(name string) !&Part {
	stock := stock_instrument(name)!

	score.part_counter++

	mut part := &Part{
		id:               'part${score.part_counter:03}'
		name:             name
		stock_instrument: stock
		current_offset:   0
		last_offset:      -1
		octave:           4
		tempo:            120
		volume:           dynamic_volumes['mf']
		track_volume:     100.0 / 127
		panning:          0.5
		midi_channel:     -1
		quantization:     0.9
		duration:         Duration{
			components: [DurationComponent(NoteLength{
				denominator: 4
			})]
		}
		time_scale:       1.0
		reference_pitch:  440.0
		voices:           new_voices()
		score:            unsafe { &score }
	}
	part.origin = part

	return part
}

// set_alias defines an alias that refers to 1 or more parts.
pub fn (mut score Score) set_alias(alias string, parts []&Part) {
	score.aliases[alias] = parts
}

// named_parts returns the parts that correspond to the provided alias.
pub fn (score &Score) named_parts(alias string) []&Part {
	return score.aliases[alias] or { []&Part{} }
}

fn stock_name_or_na(name string) string {
	instrument := stock_instrument(name) or { return 'N/A' }
	return instrument.name
}

// unnamed_parts returns the parts in the score that are not included in any
// alias, and that are instances of the stock instrument identified by `name`.
pub fn (score &Score) unnamed_parts(name string) []&Part {
	stock := stock_name_or_na(name)
	mut results := []&Part{}

	for part in score.parts {
		mut is_named_part := false
		for _, named_parts in score.aliases {
			if contains_part(named_parts, part) {
				is_named_part = true
			}
		}

		if !is_named_part && part.stock_instrument.name == stock {
			results << part
		}
	}

	return results
}

// aliased_stock_instruments returns the parts that have a dedicated alias
// (e.g. `piano "foo"`) and are instances of the stock instrument `name`.
pub fn (score &Score) aliased_stock_instruments(name string) []&Part {
	stock := stock_name_or_na(name)
	mut results := []&Part{}

	for _, named_parts in score.aliases {
		if named_parts.len == 1 && named_parts[0].stock_instrument.name == stock {
			results << named_parts[0]
		}
	}

	return results
}

// aliases_for returns the aliases in the score that correspond to a single
// part, the one provided.
pub fn (score &Score) aliases_for(part &Part) []string {
	mut results := []string{}
	for alias, parts in score.aliases {
		if parts.len == 1 && same(parts[0], part) {
			results << alias
		}
	}
	return results
}

// Once an alias is defined for a group, its individual parts can be accessed
// using the "." (dot) operator.
fn dot_access(name string) bool {
	return name.contains('.')
}

fn append_unique(mut parts []&Part, part &Part) {
	if !contains_part(parts, part) {
		parts << part
	}
}

fn determine_parts(decl PartDeclaration, mut score Score) ![]&Part {
	// e.g. foo, foo "bar"
	if decl.names.len == 1 {
		name := decl.names[0]
		named_parts := score.named_parts(name)
		unnamed_parts := score.unnamed_parts(name)
		parts_for_alias := score.named_parts(decl.alias)
		aliased_stock_instruments := score.aliased_stock_instruments(name)

		// If there is an alias, then `name` is expected to be the name of a stock
		// instrument, not the alias of an existing part.
		if decl.alias != '' && named_parts.len > 0 {
			return error('can\'t assign alias "${decl.alias}" to existing instance "${name}"')
		}

		// Can't redefine an existing alias.
		if decl.alias != '' && parts_for_alias.len > 0 {
			return error('the alias "${decl.alias}" has already been assigned to another part/group')
		}

		// Can't use both unnamed and named instances of the same instrument.
		if (decl.alias != '' && unnamed_parts.len > 0)
			|| (decl.alias == '' && aliased_stock_instruments.len > 0 && !dot_access(name)) {
			reference := if decl.alias != '' { decl.alias } else { name }
			return error('ambiguous instrument reference "${reference}": can\'t use both unnamed and named instances of the same instrument in a score')
		}

		// Always create a new part if there is an alias.
		if decl.alias != '' {
			return [score.new_part(name)!]
		}

		if named_parts.len > 0 {
			return named_parts
		}

		if unnamed_parts.len > 0 {
			return unnamed_parts
		}

		return [score.new_part(name)!]
	}

	// Guard against duplicate names, e.g. piano/piano, foo/foo.
	mut seen := map[string]bool{}
	for name in decl.names {
		if seen[name] {
			return error('Name included multiple times in group: ${name}')
		}
		seen[name] = true
	}

	// Multiple names, e.g. foo/bar, foo/bar "baz", foo/bar/baz
	mut named_parts := []&Part{}
	mut stock_parts := []&Part{}

	for name in decl.names {
		named := score.named_parts(name)
		unnamed := score.unnamed_parts(name)
		if named.len > 0 {
			named_parts << named
		} else if unnamed.len > 0 {
			stock_parts << unnamed
		} else {
			stock_parts << score.new_part(name)!
		}
	}

	// Can't use both named and stock instruments in a group.
	if named_parts.len > 0 && stock_parts.len > 0 {
		return error('invalid group "${decl.names.join('/')}": can\'t use both stock instruments and named parts')
	}

	mut parts := []&Part{}

	// Always create new parts when creating a named group consisting of stock
	// instruments.
	if decl.alias != '' && stock_parts.len > 0 {
		for name in decl.names {
			append_unique(mut parts, score.new_part(name)!)
		}
		return parts
	}

	// Named groups can overlap, so deduplicate.
	for part in named_parts {
		append_unique(mut parts, part)
	}
	for part in stock_parts {
		append_unique(mut parts, part)
	}

	return parts
}

// update_score sets the current ("active") parts, creating the referenced
// instrument instances if they don't exist yet.
pub fn (decl PartDeclaration) update_score(mut score Score) ! {
	// The beginning of a new part implicitly ends a voice group in the
	// preceding part if there is one.
	VoiceGroupEndMarker{}.update_score(mut score)!

	mut parts := determine_parts(decl, mut score)!

	// The first part added to the score is the tempo "master."
	if score.parts.len == 0 {
		parts[0].tempo_role = .master
	}

	for part in parts {
		append_unique(mut score.parts, part)
	}

	if decl.alias != '' {
		mut aliases_for_part := map[u64][]string{}
		for part in parts {
			aliases_for_part[part_key(part)] = score.aliases_for(part)
		}

		score.set_alias(decl.alias, parts)

		for part in parts {
			score.set_alias(decl.alias + '.' + part.name, [part])
			for alias in aliases_for_part[part_key(part)] {
				score.set_alias(decl.alias + '.' + alias, [part])
			}
		}
	}

	score.current_parts = parts
}

// calculate_effective_offset determines the current offset of the part,
// considering the offsets of any voices it may have.
pub fn (p &Part) calculate_effective_offset() f64 {
	if isnil(p.voices) || p.voices.voices.len == 0 {
		return p.current_offset
	}

	mut max_offset := p.current_offset
	for voice_number in p.voices.insertion_order {
		voice := p.voices.voices[voice_number] or { continue }
		if voice.current_offset > max_offset {
			max_offset = voice.current_offset
		}
	}
	return max_offset
}
