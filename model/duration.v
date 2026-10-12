module model

import math

// DurationComponent instances are added together and the sum is the total
// duration of the Duration.
pub type DurationComponent = Barline
	| Duration
	| NoteLength
	| NoteLengthBeats
	| NoteLengthMs
	| NoteLengthSeconds

// A NoteLength represents a standard note length in Western classical music
// notation, e.g. a denominator of 4 is a quarter note. Dots extend the length
// by progressively halved values.
pub struct NoteLength {
pub:
	denominator f64
	dots        int
}

// NoteLengthBeats expresses a duration as a specific number of beats.
pub struct NoteLengthBeats {
pub:
	quantity f64
}

// NoteLengthMs expresses a duration as a specific number of milliseconds.
pub struct NoteLengthMs {
pub:
	quantity f64
}

// NoteLengthSeconds expresses a duration as a specific number of seconds.
pub struct NoteLengthSeconds {
pub:
	quantity f64
}

// Duration describes the length of time occupied by a note or other event.
//
// A duration with no components means "unspecified" (Go's nil slice), in which
// case the part's default duration is used.
pub struct Duration {
pub mut:
	components []DurationComponent
}

pub fn (d Duration) is_specified() bool {
	return d.components.len > 0
}

pub fn (nl NoteLength) beats() f64 {
	return (4 / nl.denominator) * (2 - math.pow(2, f64(-nl.dots)))
}

pub fn (c DurationComponent) beats() !f64 {
	return match c {
		Barline {
			0.0
		}
		Duration {
			mut beats := 0.0
			for component in c.components {
				beats += component.beats()!
			}
			beats
		}
		NoteLength {
			c.beats()
		}
		NoteLengthBeats {
			c.quantity
		}
		NoteLengthMs {
			error('A millisecond note length cannot be expressed in beats')
		}
		NoteLengthSeconds {
			error('A second note length cannot be expressed in beats')
		}
	}
}

pub fn (c DurationComponent) ms(tempo f64) f64 {
	return match c {
		Barline {
			0.0
		}
		Duration {
			c.ms(tempo)
		}
		NoteLength {
			c.beats() * (60000 / tempo)
		}
		NoteLengthBeats {
			c.quantity * (60000 / tempo)
		}
		NoteLengthMs {
			c.quantity
		}
		NoteLengthSeconds {
			c.quantity * 1000
		}
	}
}

pub fn (c DurationComponent) validate() ! {
	match c {
		Barline {}
		Duration {
			c.validate()!
		}
		NoteLength {
			if c.denominator <= 0 {
				return error('The note length must be a positive number.')
			}
		}
		NoteLengthBeats {
			if c.quantity <= 0 {
				return error('The number of beats must be positive.')
			}
		}
		NoteLengthMs {
			if c.quantity <= 0 {
				return error('The number of milliseconds must be positive.')
			}
		}
		NoteLengthSeconds {
			if c.quantity <= 0 {
				return error('The number of seconds must be positive.')
			}
		}
	}
}

pub fn (d Duration) validate() ! {
	for component in d.components {
		component.validate()!
	}
}

pub fn (d Duration) beats() !f64 {
	return DurationComponent(d).beats()
}

pub fn (d Duration) ms(tempo f64) f64 {
	mut ms := 0.0
	for component in d.components {
		ms += component.ms(tempo)
	}
	return ms
}

pub fn (d Duration) clone() Duration {
	return Duration{
		components: d.components.clone()
	}
}

// TempoRole describes the relationship a part has with the global tempo of a
// score.
pub enum TempoRole {
	unspecified
	master
}

pub fn (tr TempoRole) str() string {
	return match tr {
		.unspecified { 'unspecified' }
		.master { 'master' }
	}
}
