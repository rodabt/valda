@[has_globals]
module model

// Alda includes a minimal Lisp as a subset of the language, in order to add
// features (mostly attribute changes) without accumulating syntax.

// parse_alda_code is set by the parser module at startup. model can't import
// parser without creating an import cycle, so parser plugs its implementation
// in here instead. Used by the `alda-code` function.
struct Hooks {
mut:
	parse_alda_code fn (string) ![]ScoreUpdate = unsafe { nil }
}

__global hooks = Hooks{}

pub fn set_alda_code_parser(f fn (string) ![]ScoreUpdate) {
	hooks.parse_alda_code = f
}

fn parse_alda_code(code string) ![]ScoreUpdate {
	if isnil(hooks.parse_alda_code) {
		return error('alda-code is not available')
	}
	return hooks.parse_alda_code(code)
}

pub type LispForm = LispDuration
	| LispFunction
	| LispList
	| LispNil
	| LispNumber
	| LispPitch
	| LispQuotedForm
	| LispScoreUpdate
	| LispSpecialFormQuote
	| LispString
	| LispSymbol

// LispSpecialFormQuote is the special form `quote`.
pub struct LispSpecialFormQuote {}

// LispNil is the value nil.
pub struct LispNil {
pub:
	source_context AldaSourceContext
}

// LispQuotedForm wraps a form by quoting it.
pub struct LispQuotedForm {
pub:
	source_context AldaSourceContext
	form           LispForm
}

pub struct LispSymbol {
pub:
	source_context AldaSourceContext
	name           string
}

pub struct LispNumber {
pub:
	source_context AldaSourceContext
	value          f64
}

pub struct LispString {
pub:
	source_context AldaSourceContext
	value          string
}

// LispScoreUpdate is a ScoreUpdate value.
pub struct LispScoreUpdate {
pub:
	score_update ScoreUpdate
}

// LispPitch is a PitchIdentifier value.
pub struct LispPitch {
pub:
	pitch PitchIdentifier
}

// LispDuration is a DurationComponent value.
pub struct LispDuration {
pub:
	component DurationComponent
}

// LispList is a list of forms. Unquoted, it's an S-expression.
pub struct LispList {
pub:
	source_context AldaSourceContext
	elements       []LispForm
}

// A FunctionSignature defines what a function does when called with arguments
// of a certain combination of types. Argument types are type strings (see
// type_string); a trailing `*` means "0 or more", and `any` matches any type.
pub struct FunctionSignature {
pub:
	argument_types []string
	implementation fn ([]LispForm) !LispForm @[required]
}

pub struct LispFunction {
pub:
	name       string
	signatures []FunctionSignature
}

// type_string returns a human-readable name of a form's type.
pub fn (f LispForm) type_string() string {
	return match f {
		LispDuration { 'duration' }
		LispFunction { 'function' }
		LispList { 'list' }
		LispNil { 'nil' }
		LispNumber { 'number' }
		LispPitch { 'pitch' }
		LispQuotedForm { 'quoted form' }
		LispScoreUpdate { 'score update' }
		LispSpecialFormQuote { 'special-form' }
		LispString { 'string' }
		LispSymbol { 'symbol' }
	}
}

pub fn (f LispForm) source_context() AldaSourceContext {
	return match f {
		LispList, LispNil, LispNumber, LispQuotedForm, LispString, LispSymbol {
			f.source_context
		}
		LispScoreUpdate {
			f.score_update.source_context()
		}
		else {
			AldaSourceContext{}
		}
	}
}

pub fn (sym LispSymbol) str() string {
	return "'" + sym.name
}

fn type_matches(expected string, form LispForm) bool {
	return expected == 'any' || expected == form.type_string()
}

fn arguments_match_signature(arguments []LispForm, signature FunctionSignature) bool {
	total := signature.argument_types.len
	if total == 0 {
		return arguments.len == 0
	}

	variadic := signature.argument_types.last().ends_with('*')
	fixed := if variadic { total - 1 } else { total }

	if variadic && arguments.len < fixed {
		return false
	}
	if !variadic && arguments.len != fixed {
		return false
	}

	for i in 0 .. fixed {
		if !type_matches(signature.argument_types[i], arguments[i]) {
			return false
		}
	}

	if arguments.len > fixed {
		variadic_type := signature.argument_types.last().trim_right('*')
		for argument in arguments[fixed..] {
			if !type_matches(variadic_type, argument) {
				return false
			}
		}
	}

	return true
}

fn argument_types_line(types []string) string {
	if types.len == 0 {
		return '(no arguments)'
	}
	return types.join(', ')
}

// operate calls the implementation whose signature matches the arguments.
pub fn (f LispFunction) operate(arguments []LispForm) !LispForm {
	for signature in f.signatures {
		if arguments_match_signature(arguments, signature) {
			return signature.implementation(arguments)
		}
	}

	expected := f.signatures.map(argument_types_line(it.argument_types)).join('    OR\n')
	got := argument_types_line(arguments.map(it.type_string()))

	return error('provided arguments do not match the signature of `${f.name}`

Expected:
${expected}

Got:
${got}')
}

// eval returns the value of a form when evaluated.
pub fn (f LispForm) eval() !LispForm {
	match f {
		LispSymbol {
			if f.name == 'quote' {
				return LispSpecialFormQuote{}
			}
			if value := lisp_environment[f.name] {
				return value
			}
			return source_errorf(f.source_context, 'unresolvable symbol: ${f.name}')
		}
		LispQuotedForm {
			return f.form
		}
		LispList {
			return f.eval()
		}
		else {
			return f
		}
	}
}

// eval treats the (unquoted) list as an S-expression: the first form is the
// operator and the remaining forms are the arguments.
pub fn (l LispList) eval() !LispForm {
	if l.elements.len == 0 {
		return source_errorf(l.source_context, 'cannot evaluate an empty list')
	}

	operator := l.elements[0].eval()!

	if operator is LispSpecialFormQuote {
		if l.elements.len - 1 > 1 {
			return error('expected 1 argument to quote, got ${l.elements.len - 1}')
		}
		if l.elements.len < 2 {
			return LispNil{}
		}
		return l.elements[1]
	}

	mut arguments := []LispForm{cap: l.elements.len - 1}
	for argument in l.elements[1..] {
		arguments << argument.eval()!
	}

	if operator is LispFunction {
		return operator.operate(arguments) or { return source_error(l.source_context, err) }
	}

	return source_errorf(l.source_context, 'value is not an Operator: ${operator.type_string()}')
}

fn unpack_score_update(form LispForm) ScoreUpdate {
	if form is LispScoreUpdate {
		return form.score_update
	}
	return LispNil{}
}

// update_score evaluates the S-expression and uses the resulting value to
// update the score.
pub fn (l LispList) update_score(mut score Score) ! {
	result := l.eval()!
	score.update(unpack_score_update(result))!
}

// ----------------------------------------------------------------------------
// Argument helpers

fn as_number(form LispForm) LispNumber {
	return form as LispNumber
}

fn positive_number(form LispForm) !f64 {
	number := as_number(form)
	if number.value < 1 {
		return source_errorf(number.source_context, 'expected positive number, got ${number.value:.6f}')
	}
	return number.value
}

fn non_negative_number(form LispForm) !f64 {
	number := as_number(form)
	if number.value < 0 {
		return source_errorf(number.source_context, 'expected non-negative number, got ${number.value:.6f}')
	}
	return number.value / 100
}

fn integer(form LispForm) !int {
	number := as_number(form)
	if number.value != f64(int(number.value)) {
		return source_errorf(number.source_context, 'expected integer, got ${number.value:.6f}')
	}
	return int(number.value)
}

fn integer_in_range(form LispForm, lower int, upper int) !int {
	number := as_number(form)
	i := integer(form)!
	if i < lower || i > upper {
		return source_errorf(number.source_context, 'expected integer in range ${lower}-${upper}, got ${i}')
	}
	return i
}

fn percentage(form LispForm) !f64 {
	number := as_number(form)
	if number.value < 0 || number.value > 100 {
		return source_errorf(number.source_context, 'value not between 0 and 100: ${number.value:.6f}')
	}
	return number.value / 100
}

fn is_digit(c u8) bool {
	return c >= `0` && c <= `9`
}

// parse_note_length parses a note length string like "4", "2..", "1.5".
pub fn parse_note_length(str string) !NoteLength {
	if str.len == 0 || !is_digit(str[0]) {
		return error('invalid note length: "${str}"')
	}

	mut i := 0
	for i < str.len && is_digit(str[i]) {
		i++
	}

	// A period followed by more digits is a decimal point.
	if i < str.len && str[i] == `.` && i + 1 < str.len && is_digit(str[i + 1]) {
		i++
		for i < str.len && is_digit(str[i]) {
			i++
		}
	}

	denominator := str[..i].f64()

	// Any periods remaining are dots.
	mut dots := 0
	for i < str.len && str[i] == `.` {
		dots++
		i++
	}

	// Mirrors Alda's (lenient) check for trailing garbage.
	if i < str.len - 1 {
		return error('invalid note length: "${str}"')
	}

	return NoteLength{
		denominator: denominator
		dots:        dots
	}
}

fn duration_from_string(form LispForm) !Duration {
	s := form as LispString
	mut d := Duration{}
	for part in s.value.split('~') {
		nl := parse_note_length(part) or { return source_error(s.source_context, err) }
		d.components << nl
	}
	return d
}

fn is_note_letter(c u8) bool {
	return c >= `a` && c <= `g`
}

fn letter_and_accidentals(str string) !(NoteLetter, []Accidental) {
	validity_error := 'invalid "letter and accidentals" component: "${str}"'

	if str.len < 2 || !is_note_letter(str[0]) {
		return error(validity_error)
	}

	letter := new_note_letter(rune(str[0]))!
	mut accidentals := []Accidental{}

	for c in str[1..] {
		match c {
			`+` { accidentals << .sharp }
			`-` { accidentals << .flat }
			else { return error(validity_error) }
		}
	}

	return letter, accidentals
}

fn key_signature_from_string(form LispForm) !KeySignature {
	s := form as LispString
	mut keysig := KeySignature{}
	for str in s.value.fields() {
		letter, accidentals := letter_and_accidentals(str) or {
			return source_error(s.source_context, err)
		}
		keysig.set(letter, accidentals)
	}
	return keysig
}

fn forms_str(forms []LispForm) string {
	return '[' + forms.map(it.type_string()).join(' ') + ']'
}

fn scale_type(forms []LispForm) !ScaleType {
	validity_error := 'invalid scale type: ${forms_str(forms)}'

	// All currently supported scale types are a single word.
	if forms.len != 1 {
		return error(validity_error)
	}

	form := forms[0]
	if form is LispSymbol {
		return match form.name {
			'major', 'ionian' { ScaleType.ionian }
			'dorian' { ScaleType.dorian }
			'phrygian' { ScaleType.phrygian }
			'lydian' { ScaleType.lydian }
			'mixolydian' { ScaleType.mixolydian }
			'minor', 'aeolian' { ScaleType.aeolian }
			'locrian' { ScaleType.locrian }
			else { error(validity_error) }
		}
	}

	return error(validity_error)
}

fn key_signature_from_scale_name(forms []LispForm) !KeySignature {
	validity_error := 'invalid scale name: ${forms_str(forms)}'

	first := forms[0]
	if first !is LispSymbol {
		return error(validity_error)
	}
	name := (first as LispSymbol).name
	if name.len != 1 {
		return error(validity_error)
	}

	mut tonic := LetterAndAccidentals{
		note_letter: new_note_letter(rune(name[0]))!
	}
	mut passed_accidentals := false
	mut remaining := []LispForm{}

	for form in forms[1..] {
		if form is LispSymbol {
			if accidental := new_accidental(form.name) {
				if passed_accidentals {
					return error(validity_error)
				}
				tonic.accidentals << accidental
				tonic.has_accidentals = true
				continue
			}
			passed_accidentals = true
			remaining << form
		} else {
			return error(validity_error)
		}
	}

	return key_signature_from_scale(tonic, scale_type(remaining)!)
}

fn key_signature_from_accidentals(forms []LispForm) !KeySignature {
	validity_error := 'expected pairs of note letter and accidentals, got ${forms_str(forms)}'

	// e.g. (key-signature '(b (flat) e (flat)))
	if forms.len % 2 != 0 {
		return error(validity_error)
	}

	mut keysig := KeySignature{}

	for i := 0; i < forms.len; i += 2 {
		letter_form := forms[i]
		if letter_form !is LispSymbol {
			return error(validity_error)
		}
		letter := new_note_letter(rune((letter_form as LispSymbol).name[0]))!

		accidentals_form := forms[i + 1]
		if accidentals_form !is LispList {
			return error(validity_error)
		}

		mut accidentals := []Accidental{}
		for form in (accidentals_form as LispList).elements {
			if form is LispSymbol {
				match form.name {
					'flat' { accidentals << .flat }
					'sharp' { accidentals << .sharp }
					else { return error(validity_error) }
				}
			} else {
				return error(validity_error)
			}
		}

		keysig.set(letter, accidentals)
	}

	return keysig
}

fn key_signature_from_list(form LispForm) !KeySignature {
	list := form as LispList
	forms := list.elements

	if forms.len < 2 {
		return source_errorf(list.source_context, 'invalid key signature: ${forms_str(forms)}')
	}

	second := forms[1]
	if second is LispSymbol {
		return key_signature_from_scale_name(forms) or {
			return source_error(list.source_context, err)
		}
	}
	if second is LispList {
		return key_signature_from_accidentals(forms) or {
			return source_error(list.source_context, err)
		}
	}

	return source_errorf(list.source_context, 'invalid key signature: ${forms_str(forms)}')
}

// ----------------------------------------------------------------------------
// The environment of built-in functions

struct AttributeSignature {
	argument_types []string
	implementation fn ([]LispForm) !PartUpdate @[required]
}

fn sig(types []string, implementation fn ([]LispForm) !LispForm) FunctionSignature {
	return FunctionSignature{
		argument_types: types
		implementation: implementation
	}
}

fn attr(types []string, implementation fn ([]LispForm) !PartUpdate) AttributeSignature {
	return AttributeSignature{
		argument_types: types
		implementation: implementation
	}
}

fn defn(mut env map[string]LispForm, name string, signatures []FunctionSignature) {
	env[name] = LispFunction{
		name:       name
		signatures: signatures
	}
}

// defattribute defines `name` (a local attribute change) and `name!` (a global
// attribute change) for each name.
fn defattribute(mut env map[string]LispForm, names []string, signatures []AttributeSignature) {
	for name in names {
		for global in [false, true] {
			mut fsigs := []FunctionSignature{}
			for s in signatures {
				implementation := s.implementation
				fsigs << FunctionSignature{
					argument_types: s.argument_types
					implementation: fn [implementation, global] (args []LispForm) !LispForm {
						part_update := implementation(args)!
						if global {
							return LispScoreUpdate{
								score_update: GlobalAttributeUpdate{
									part_update: part_update
								}
							}
						}
						return LispScoreUpdate{
							score_update: AttributeUpdate{
								part_update: part_update
							}
						}
					}
				}
			}
			fname := if global { name + '!' } else { name }
			defn(mut env, fname, fsigs)
		}
	}
}

const lisp_environment = build_environment()

fn build_environment() map[string]LispForm {
	mut env := map[string]LispForm{}

	// Current octave. Used to calculate the pitch of notes.
	defattribute(mut env, ['octave'], [
		attr(['number'], fn (args []LispForm) !PartUpdate {
			return OctaveSet{
				octave_number: integer(args[0])!
			}
		}),
		attr(['symbol'], fn (args []LispForm) !PartUpdate {
			symbol := args[0] as LispSymbol
			return match symbol.name {
				'up' { PartUpdate(OctaveUp{}) }
				'down' { PartUpdate(OctaveDown{}) }
				else { source_errorf(symbol.source_context, 'invalid argument to `octave`: ${symbol}') }
			}
		}),
	])

	// Current tempo. Used to calculate the duration of notes.
	defattribute(mut env, ['tempo'], [
		attr(['number'], fn (args []LispForm) !PartUpdate {
			return TempoSet{
				tempo: positive_number(args[0])!
			}
		}),
		attr(['number', 'number'], fn (args []LispForm) !PartUpdate {
			note_length := positive_number(args[0])!
			pseudo_bpm := positive_number(args[1])!
			return TempoSet{
				tempo: NoteLength{
					denominator: note_length
				}.beats() * pseudo_bpm
			}
		}),
		attr(['string', 'number'], fn (args []LispForm) !PartUpdate {
			d := duration_from_string(args[0])!
			pseudo_bpm := positive_number(args[1])!
			return TempoSet{
				tempo: d.beats()! * pseudo_bpm
			}
		}),
	])

	// Express tempo in terms of metric modulation, where the new note takes the
	// same amount of time (one beat) as the old note.
	defattribute(mut env, ['metric-modulation'], [
		attr(['number', 'number'], fn (args []LispForm) !PartUpdate {
			old_beats := NoteLength{
				denominator: positive_number(args[0])!
			}.beats()
			new_beats := NoteLength{
				denominator: positive_number(args[1])!
			}.beats()
			return MetricModulation{
				ratio: new_beats / old_beats
			}
		}),
		attr(['number', 'string'], fn (args []LispForm) !PartUpdate {
			old_beats := NoteLength{
				denominator: positive_number(args[0])!
			}.beats()
			new_beats := duration_from_string(args[1])!.beats()!
			return MetricModulation{
				ratio: new_beats / old_beats
			}
		}),
		attr(['string', 'number'], fn (args []LispForm) !PartUpdate {
			old_beats := duration_from_string(args[0])!.beats()!
			new_beats := NoteLength{
				denominator: positive_number(args[1])!
			}.beats()
			return MetricModulation{
				ratio: new_beats / old_beats
			}
		}),
		attr(['string', 'string'], fn (args []LispForm) !PartUpdate {
			old_beats := duration_from_string(args[0])!.beats()!
			new_beats := duration_from_string(args[1])!.beats()!
			return MetricModulation{
				ratio: new_beats / old_beats
			}
		}),
	])

	// The percentage of a note that is heard.
	defattribute(mut env, ['quantization', 'quantize', 'quant'], [
		attr(['number'], fn (args []LispForm) !PartUpdate {
			return QuantizationSet{
				quantization: non_negative_number(args[0])!
			}
		}),
	])

	// Current volume. For MIDI purposes, the velocity of individual notes.
	defattribute(mut env, ['volume', 'vol'], [
		attr(['number'], fn (args []LispForm) !PartUpdate {
			return VolumeSet{
				volume: percentage(args[0])!
			}
		}),
	])

	// Volume for the track as a whole (MIDI expression).
	defattribute(mut env, ['track-volume', 'track-vol'], [
		attr(['number'], fn (args []LispForm) !PartUpdate {
			return TrackVolumeSet{
				track_volume: percentage(args[0])!
			}
		}),
	])

	// Dynamic markings, e.g. (pp), (ff)
	for marking, _ in dynamic_volumes {
		m := marking
		defattribute(mut env, [m], [
			attr([], fn [m] (args []LispForm) !PartUpdate {
				return DynamicMarking{
					marking: m
				}
			}),
		])
	}

	// Current panning. 0 = hard left, 100 = hard right.
	defattribute(mut env, ['panning', 'pan'], [
		attr(['number'], fn (args []LispForm) !PartUpdate {
			return PanningSet{
				panning: percentage(args[0])!
			}
		}),
	])

	// Default note duration in beats.
	defattribute(mut env, ['set-duration'], [
		attr(['number'], fn (args []LispForm) !PartUpdate {
			return DurationSet{
				duration: Duration{
					components: [
						DurationComponent(NoteLengthBeats{
							quantity: positive_number(args[0])!
						}),
					]
				}
			}
		}),
	])

	// Default note duration in milliseconds.
	defattribute(mut env, ['set-duration-ms'], [
		attr(['number'], fn (args []LispForm) !PartUpdate {
			return DurationSet{
				duration: Duration{
					components: [
						DurationComponent(NoteLengthMs{
							quantity: positive_number(args[0])!
						}),
					]
				}
			}
		}),
	])

	// Default note duration, expressed as a note length, e.g. 4 or "2..", or
	// multiple note lengths tied together, e.g. "1~1".
	defattribute(mut env, ['set-note-length'], [
		attr(['number'], fn (args []LispForm) !PartUpdate {
			return DurationSet{
				duration: Duration{
					components: [
						DurationComponent(NoteLength{
							denominator: positive_number(args[0])!
						}),
					]
				}
			}
		}),
		attr([
			'string',
		], fn (args []LispForm) !PartUpdate {
			return DurationSet{
				duration: duration_from_string(args[0])!
			}
		}),
	])

	defattribute(mut env, ['key-signature', 'key-sig'], [
		attr(['string'], fn (args []LispForm) !PartUpdate {
			return KeySignatureSet{
				key_signature: key_signature_from_string(args[0])!
			}
		}),
		attr(['list'], fn (args []LispForm) !PartUpdate {
			return KeySignatureSet{
				key_signature: key_signature_from_list(args[0])!
			}
		}),
	])

	// The number of semitones to transpose (negative = down).
	defattribute(mut env, ['transposition', 'transpose'], [
		attr(['number'], fn (args []LispForm) !PartUpdate {
			return TranspositionSet{
				semitones: integer(args[0])!
			}
		}),
	])

	// The reference pitch, expressed as the frequency of A4 in Hz.
	defattribute(mut env, ['reference-pitch', 'tuning-constant'], [
		attr(['number'], fn (args []LispForm) !PartUpdate {
			return ReferencePitchSet{
				frequency: positive_number(args[0])!
			}
		}),
	])

	// The MIDI channel to use.
	defattribute(mut env, ['midi-channel'], [
		attr(['number'], fn (args []LispForm) !PartUpdate {
			return MidiChannelSet{
				channel_number: integer_in_range(args[0], 0, 15)!
			}
		}),
	])

	defn(mut env, 'list', [
		sig(['any*'], fn (args []LispForm) !LispForm {
			return LispList{
				elements: args
			}
		}),
	])

	defn(mut env, 'ms', [
		sig(['number'], fn (args []LispForm) !LispForm {
			return LispDuration{
				component: NoteLengthMs{
					quantity: positive_number(args[0])!
				}
			}
		}),
	])

	defn(mut env, 'note-length', [
		sig(['number'], fn (args []LispForm) !LispForm {
			return LispDuration{
				component: NoteLength{
					denominator: positive_number(args[0])!
				}
			}
		}),
		sig(['string'], fn (args []LispForm) !LispForm {
			return LispDuration{
				component: parse_note_length((args[0] as LispString).value)!
			}
		}),
	])

	defn(mut env, 'alda-code', [
		sig(['string'], fn (args []LispForm) !LispForm {
			updates := parse_alda_code((args[0] as LispString).value)!
			return LispScoreUpdate{
				score_update: EventSequence{
					events: updates
				}
			}
		}),
	])

	defn(mut env, 'duration', [
		sig(['duration*'], fn (args []LispForm) !LispForm {
			mut d := Duration{}
			for arg in args {
				d.components << (arg as LispDuration).component
			}
			return LispDuration{
				component: d
			}
		}),
	])

	defn(mut env, 'midi-note', [
		sig(['number'], fn (args []LispForm) !LispForm {
			return LispPitch{
				pitch: MidiNoteNumber{
					midi_note: integer(args[0])!
				}
			}
		}),
	])

	defn(mut env, 'pitch', [
		sig(['list'], fn (args []LispForm) !LispForm {
			forms := (args[0] as LispList).elements
			validity_error := 'invalid letter/accidentals: ${forms_str(forms)}'

			if forms.len == 0 {
				return error(validity_error)
			}

			first := forms[0]
			if first !is LispSymbol || (first as LispSymbol).name.len != 1 {
				return error(validity_error)
			}

			mut pitch := LetterAndAccidentals{
				note_letter: new_note_letter(rune((first as LispSymbol).name[0]))!
			}

			if forms.len > 1 {
				pitch.has_accidentals = true
				for form in forms[1..] {
					if form is LispSymbol {
						pitch.accidentals << new_accidental(form.name)!
					} else {
						return error(validity_error)
					}
				}
			}

			return LispPitch{
				pitch: pitch
			}
		}),
	])

	defn(mut env, 'note', [
		sig(['pitch'], fn (args []LispForm) !LispForm {
			return LispScoreUpdate{
				score_update: Note{
					pitch: (args[0] as LispPitch).pitch
				}
			}
		}),
		sig(['pitch', 'duration'], fn (args []LispForm) !LispForm {
			return LispScoreUpdate{
				score_update: Note{
					pitch:    (args[0] as LispPitch).pitch
					duration: Duration{
						components: [(args[1] as LispDuration).component]
					}
				}
			}
		}),
	])

	defn(mut env, 'pause', [
		sig([], fn (args []LispForm) !LispForm {
			return LispScoreUpdate{
				score_update: Rest{}
			}
		}),
		sig(['duration'], fn (args []LispForm) !LispForm {
			return LispScoreUpdate{
				score_update: Rest{
					duration: Duration{
						components: [(args[0] as LispDuration).component]
					}
				}
			}
		}),
	])

	defn(mut env, 'slur', [
		sig(['score update'], fn (args []LispForm) !LispForm {
			u := (args[0] as LispScoreUpdate).score_update
			if u is Note {
				mut note := u
				note.slurred = true
				return LispScoreUpdate{
					score_update: note
				}
			}
			return error('only notes can be slurred. Expected Note, got: ${u.type_name()}')
		}),
	])

	// TODO (as in Alda): support groups and aliases in `part`.
	defn(mut env, 'part', [
		sig(['string'], fn (args []LispForm) !LispForm {
			return LispScoreUpdate{
				score_update: PartDeclaration{
					names: [(args[0] as LispString).value]
				}
			}
		}),
	])

	return env
}
