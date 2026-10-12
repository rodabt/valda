module model

import math

// ScaleType represents a type of scale or mode, e.g. major, minor.
pub enum ScaleType {
	ionian
	dorian
	phrygian
	lydian
	mixolydian
	aeolian
	locrian
}

// KeySignature maps note letters to accidentals. Letters that are absent from
// the map are not part of the key signature. This allows standard key
// signatures as well as unconventional ones like {B: [flat, flat], G: [sharp]}.
pub struct KeySignature {
pub mut:
	entries map[int][]Accidental
}

pub fn (ks KeySignature) accidentals(letter NoteLetter) []Accidental {
	return ks.entries[int(letter)] or { []Accidental{} }
}

pub fn (ks KeySignature) has(letter NoteLetter) bool {
	return int(letter) in ks.entries
}

pub fn (mut ks KeySignature) set(letter NoteLetter, accidentals []Accidental) {
	ks.entries[int(letter)] = accidentals
}

pub fn (ks KeySignature) clone() KeySignature {
	mut entries := map[int][]Accidental{}
	for k, v in ks.entries {
		entries[k] = v.clone()
	}
	return KeySignature{
		entries: entries
	}
}

// str returns the key signature as a string like "f+ c+". Letters are listed in
// circle-of-fifths order (the order of sharps, or of flats), as in sheet music.
// (Alda's Go client iterates a map here, so its order is nondeterministic.)
pub fn (ks KeySignature) str() string {
	mut all_flats := true
	for _, accidentals in ks.entries {
		if accidentals.any(it != .flat) {
			all_flats = false
		}
	}
	order := if all_flats { order_of_flats } else { order_of_sharps }

	mut laas := []string{}
	for letter in order {
		accidentals := ks.entries[int(letter)] or { continue }
		mut laa := [u8(`a` + int(letter))].bytestr()
		for acc in accidentals {
			laa += match acc {
				.flat { '-' }
				.natural { '_' }
				.sharp { '+' }
			}
		}
		laas << laa
	}
	return laas.join(' ')
}

const all_letters = [NoteLetter.a, .b, .c, .d, .e, .f, .g]

fn shift_key(k KeySignature, this Accidental, that Accidental) KeySignature {
	mut result := KeySignature{}

	for letter in all_letters {
		if !k.has(letter) {
			result.set(letter, [this])
			continue
		}

		accidentals := k.accidentals(letter)

		// Shifting the other way cancels `that` out, so this letter is not part of
		// the new key signature.
		if accidentals.len == 1 && accidentals[0] == that {
			continue
		}

		mut shifted := []Accidental{}
		mut contains_that := false
		for accidental in accidentals {
			if accidental == this || contains_that {
				shifted << accidental
			} else {
				// Dropping one `that` accidental shifts a semitone toward `this`.
				contains_that = true
			}
		}

		if !contains_that {
			shifted << this
		}

		result.set(letter, shifted)
	}

	return result
}

// flatten returns the key signature one semitone lower.
pub fn (k KeySignature) flatten() KeySignature {
	return shift_key(k, .flat, .sharp)
}

// sharpen returns the key signature one semitone higher.
pub fn (k KeySignature) sharpen() KeySignature {
	return shift_key(k, .sharp, .flat)
}

const order_of_flats = [NoteLetter.b, .e, .a, .d, .g, .c, .f]
const order_of_sharps = [NoteLetter.f, .c, .g, .d, .a, .e, .b]

fn partial_circle_of_fifths(scale_type ScaleType, letter NoteLetter) int {
	start := match scale_type {
		.ionian { -1 }
		.dorian { -3 }
		.phrygian { -5 }
		.lydian { 0 }
		.mixolydian { -2 }
		.aeolian { -4 }
		.locrian { -6 }
	}
	return start + order_of_sharps.index(letter)
}

// key_signature_from_circle_of_fifths returns a key signature given a placement
// in the circle of fifths. Negative numbers are flats, positive are sharps.
pub fn key_signature_from_circle_of_fifths(fifths int) KeySignature {
	mut keysig := KeySignature{}
	if fifths == 0 {
		return keysig
	}

	order := if fifths > 0 { order_of_sharps } else { order_of_flats }
	accidental := if fifths > 0 { Accidental.sharp } else { Accidental.flat }

	for i in 0 .. int(math.abs(fifths)) {
		letter := order[i % order.len]
		mut accidentals := keysig.accidentals(letter)
		accidentals << accidental
		keysig.set(letter, accidentals)
	}

	return keysig
}

// key_signature_from_scale returns a key signature given a tonic note and a
// scale type.
pub fn key_signature_from_scale(tonic LetterAndAccidentals, scale_type ScaleType) KeySignature {
	mut keysig := key_signature_from_circle_of_fifths(partial_circle_of_fifths(scale_type,
		tonic.note_letter))

	for accidental in tonic.accidentals {
		match accidental {
			.flat { keysig = keysig.flatten() }
			.sharp { keysig = keysig.sharpen() }
			.natural {}
		}
	}

	return keysig
}
