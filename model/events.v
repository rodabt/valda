module model

// An EventSequence is an ordered sequence of events.
pub struct EventSequence {
pub:
	source_context AldaSourceContext
	events         []ScoreUpdate
}

// A Barline has no audible effect on a score. Its purpose is to visually
// separate elements in an Alda source file.
pub struct Barline {
pub:
	source_context AldaSourceContext
}

// A Marker gives a name to a point in time in a score.
pub struct Marker {
pub:
	source_context AldaSourceContext
	name           string
}

// update_score stores the current point in time as a named marker. All current
// parts are expected to be at the same offset.
pub fn (marker Marker) update_score(mut score Score) ! {
	if score.current_parts.len == 0 {
		return error("can't define marker \"${marker.name}\" outside the context of a part")
	}

	offset := score.current_parts[0].current_offset
	for part in score.current_parts[1..] {
		if part.current_offset != offset {
			return error('offset of marker "${marker.name}" unclear')
		}
	}

	score.markers[marker.name] = offset
}

// AtMarker sets the current parts' offset to a point in time denoted
// previously by a Marker.
pub struct AtMarker {
pub:
	source_context AldaSourceContext
	name           string
}

pub fn (at_marker AtMarker) update_score(mut score Score) ! {
	score.apply_global_attributes()!

	offset := score.markers[at_marker.name] or {
		return error('Marker undefined: ${at_marker.name}')
	}

	for mut part in score.current_parts {
		part.last_offset = part.current_offset
		part.current_offset = offset
	}
}

// RepetitionRange is an inclusive range of repetition numbers, e.g. 1-4.
pub struct RepetitionRange {
pub:
	first int
	last  int
}

// A Repeat expression repeats an event a number of times.
pub struct Repeat {
pub:
	source_context AldaSourceContext
	event          ScoreUpdate
	times          int
}

pub fn (repeat Repeat) update_score(mut score Score) ! {
	previous := score.current_parts.map(it.current_repetition)

	for repetition in 1 .. repeat.times + 1 {
		for mut part in score.current_parts {
			part.current_repetition = repetition
		}
		score.update(repeat.event)!
	}

	for i, mut part in score.current_parts {
		if i < previous.len {
			part.current_repetition = previous[i]
		}
	}
}

// OnRepetitions specifies that an event should only occur on certain
// repetition numbers through a repeated pattern.
pub struct OnRepetitions {
pub:
	source_context AldaSourceContext
	repetitions    []RepetitionRange
	event          ScoreUpdate
}

pub fn (or_ OnRepetitions) applies_to(repetition int) bool {
	for r in or_.repetitions {
		if r.first <= repetition && repetition <= r.last {
			return true
		}
	}
	return false
}

pub fn (or_ OnRepetitions) update_score(mut score Score) ! {
	for part in score.current_parts {
		if or_.applies_to(part.current_repetition) {
			score.update(or_.event)!
		}
	}
}

// A VariableDefinition stores a sequence of ScoreUpdates under a name.
pub struct VariableDefinition {
pub:
	source_context AldaSourceContext
	variable_name  string
	events         []ScoreUpdate
}

pub fn (vd VariableDefinition) update_score(mut score Score) ! {
	score.variables[vd.variable_name] = variable_values(vd.events, score)!
}

// A VariableReference dereferences a stored variable, using its events to
// update the score.
pub struct VariableReference {
pub:
	source_context AldaSourceContext
	variable_name  string
}

pub fn (score &Score) get_variable(name string) ![]ScoreUpdate {
	return score.variables[name] or { return error('undefined variable: ${name}') }
}

pub fn (vr VariableReference) update_score(mut score Score) ! {
	events := score.get_variable(vr.variable_name)!
	for event in events {
		event.update_score(mut score)!
	}
}
