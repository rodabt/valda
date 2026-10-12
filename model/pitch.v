module model

// NoteLetter represents a note letter in Western standard musical notation.
pub enum NoteLetter {
	a
	b
	c
	d
	e
	f
	g
}

const note_letter_intervals = [9, 11, 0, 2, 4, 5, 7] // a b c d e f g

pub fn (nl NoteLetter) str() string {
	return match nl {
		.a { 'A' }
		.b { 'B' }
		.c { 'C' }
		.d { 'D' }
		.e { 'E' }
		.f { 'F' }
		.g { 'G' }
	}
}

// new_note_letter returns the NoteLetter that corresponds to the provided
// character, e.g. `a` => .a
pub fn new_note_letter(letter rune) !NoteLetter {
	return match letter {
		`a` { NoteLetter.a }
		`b` { NoteLetter.b }
		`c` { NoteLetter.c }
		`d` { NoteLetter.d }
		`e` { NoteLetter.e }
		`f` { NoteLetter.f }
		`g` { NoteLetter.g }
		else { error('invalid note letter: ${letter}') }
	}
}

// An Accidental is an accidental (flat, sharp, or natural).
pub enum Accidental {
	flat
	natural
	sharp
}

pub fn (acc Accidental) str() string {
	return match acc {
		.flat { 'flat' }
		.natural { 'natural' }
		.sharp { 'sharp' }
	}
}

pub fn new_accidental(accidental string) !Accidental {
	return match accidental {
		'flat' { Accidental.flat }
		'natural' { Accidental.natural }
		'sharp' { Accidental.sharp }
		else { error('invalid accidental: ${accidental}') }
	}
}

// PitchIdentifier defines how a pitch is specified and determined.
pub type PitchIdentifier = LetterAndAccidentals | MidiNoteNumber

// LetterAndAccidentals specifies a pitch as a note letter and (optional)
// accidentals. `has_accidentals` distinguishes "no accidentals given" (use the
// key signature) from an explicitly empty list.
pub struct LetterAndAccidentals {
pub mut:
	note_letter     NoteLetter
	accidentals     []Accidental
	has_accidentals bool
}

// MidiNoteNumber specifies a pitch as a MIDI note number.
pub struct MidiNoteNumber {
pub:
	midi_note int
}

pub fn (p PitchIdentifier) calculate_midi_note(octave int, key_signature KeySignature, transposition int) int {
	match p {
		LetterAndAccidentals {
			mut base := ((octave + 1) * 12) + note_letter_intervals[int(p.note_letter)]
			accidentals := if p.has_accidentals {
				p.accidentals
			} else {
				key_signature.accidentals(p.note_letter)
			}
			for accidental in accidentals {
				match accidental {
					.flat { base-- }
					.sharp { base++ }
					.natural {}
				}
			}
			return base + transposition
		}
		MidiNoteNumber {
			return p.midi_note + transposition
		}
	}
}
