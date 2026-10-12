module musicxml

import encoding.xml
import math
import model

// Imports MusicXML (score-partwise) into Alda score updates. A port of the
// importer in Alda's Go client.

// Part-specific import state.
@[heap]
struct Part {
mut:
	instruments []string
	divisions   int = 1 // set in the first measure
	beats       f64
	updates     []model.ScoreUpdate
	voices      map[int]&Voice
	current     &Voice = unsafe { nil }
	// For unpitched percussion parts: instrument ID => MIDI note
	unpitched map[string]int
	alias     string
	// One optimizer per part, used as voices are collapsed.
	opt &Optimizer = new_optimizer()
}

// Voice-specific import state.
@[heap]
struct Voice {
mut:
	// A single event sequence, so that recursion always works.
	updates []model.ScoreUpdate = [model.ScoreUpdate(model.EventSequence{})]
	beats   f64
	octave  int = 4
	// Slurs can be nested; a note is slurred when the depth is > 0.
	slurs int
	// Alda notes have no octave, so the octave is tracked to handle repeats.
	section_start_octave int = 4
	ending_start_octave  int = 4
}

fn new_voice() &Voice {
	return &Voice{}
}

fn (v &Voice) score_updates() []model.ScoreUpdate {
	return events_of(v.updates[0])
}

// is_effectively_empty: no updates, or just an empty repeat.
fn (v &Voice) is_effectively_empty() bool {
	updates := v.score_updates()
	if updates.len == 1 {
		u := updates[0]
		if u is model.Repeat {
			if events_of(u.event).len == 0 {
				return true
			}
		}
	}
	return updates.len == 0
}

fn (mut part Part) collapse_voices(end bool) {
	if part.voices.len == 1 {
		// A single voice gets no voice marker.
		if !part.current.is_effectively_empty() {
			part.updates << part.opt.optimize(part.current.score_updates())
			mut v := new_voice()
			v.octave = -1 // force re-setting of the octave
			// NB: As in Alda, `current` isn't updated here; it's switched to the
			// new voice when the next note with a <voice> (or measure) comes up.
			part.voices[1] = v
			part.beats = 0
		}
		return
	}

	// Process voices in order of voice number.
	mut any_voice_updates := false
	mut voice_number := 1
	mut voices_left := part.voices.len
	for voices_left > 0 {
		if voice := part.voices[voice_number] {
			if !voice.is_effectively_empty() {
				any_voice_updates = true
				part.updates << model.VoiceMarker{
					voice_number: voice_number
				}
				part.updates << part.opt.optimize(voice.score_updates())
				mut v := new_voice()
				v.octave = -1
				part.voices[voice_number] = v
			}
			voices_left--
		}
		voice_number++
	}

	if any_voice_updates {
		part.current = part.voices[1] or { part.current }
		part.beats = 0
		if end {
			part.updates << model.VoiceGroupEndMarker{}
		}
	}
}

fn (mut part Part) generate_score_updates() []model.ScoreUpdate {
	part.collapse_voices(false)
	mut result := [
		model.ScoreUpdate(model.PartDeclaration{
			names: part.instruments
			alias: part.alias
		}),
	]
	result << part.updates
	return result
}

struct NestedIndex {
	indices []int
}

fn (ni NestedIndex) last() int {
	return ni.indices.last()
}

// last_diff returns the difference between indices at the deepest common
// level.
fn last_diff(minuend NestedIndex, subtrahend NestedIndex) int {
	index := math.min(minuend.indices.len, subtrahend.indices.len) - 1
	return minuend.indices[index] - subtrahend.indices[index]
}

@[heap]
struct Importer {
mut:
	parts        map[string]&Part
	current_part &Part = unsafe { nil }
	// Tags of unsupported elements already warned about.
	unsupported []string
}

fn (mut imp Importer) part() &Part {
	return imp.current_part
}

fn (mut imp Importer) voice() &Voice {
	return imp.current_part.current
}

fn (mut imp Importer) generate_score_updates() []model.ScoreUpdate {
	mut ids := imp.parts.keys()
	ids.sort()
	mut updates := []model.ScoreUpdate{}
	for id in ids {
		mut part := imp.parts[id] or { continue }
		updates << part.generate_score_updates()
	}
	return updates
}

// flat_updates returns the base-level updates of the current voice.
fn (mut imp Importer) flat_updates() []model.ScoreUpdate {
	return imp.voice().score_updates()
}

// updates returns the current list of updates to import into.
fn (mut imp Importer) updates() []model.ScoreUpdate {
	import_into, _ := imp.find_last(filter_nested_importable_update)
	if u := import_into {
		return get_nested_updates(u, true) or { []model.ScoreUpdate{} }
	}
	return []
}

fn (mut imp Importer) last() ?model.ScoreUpdate {
	updates := imp.updates()
	if updates.len == 0 {
		return none
	}
	return updates.last()
}

// append appends updates to the current list to import into.
fn (mut imp Importer) append(new_updates ...model.ScoreUpdate) {
	_, ni := imp.find_last(filter_nested_importable_update)
	imp.modify_at(ni, fn [new_updates] (update model.ScoreUpdate) model.ScoreUpdate {
		modified, _ := modify_nested_updates(update, fn [new_updates] (updates []model.ScoreUpdate) []model.ScoreUpdate {
			mut result := updates.clone()
			result << new_updates
			return result
		})
		return modified
	})
}

// append_part_attrs appends attribute updates that apply to the whole part,
// closing out any ongoing voices.
fn (mut imp Importer) append_part_attrs(update model.ScoreUpdate) {
	mut part := imp.current_part
	part.collapse_voices(true)
	// Optimized, to catch key signature changes.
	part.updates << part.opt.optimize([update])
}

// set_all replaces the updates in the current list to import into.
fn (mut imp Importer) set_all(new_updates []model.ScoreUpdate) {
	_, ni := imp.find_last(filter_nested_importable_update)
	imp.modify_at(ni, fn [new_updates] (update model.ScoreUpdate) model.ScoreUpdate {
		return set_nested_updates(update, new_updates)
	})
}

fn (mut imp Importer) recount_beats() {
	mut voice := imp.voice()
	beats := round_if_close_enough(get_beats(...voice.updates))
	imp.current_part.beats = beats
	voice.beats = beats
}

fn modify_nested_path(update model.ScoreUpdate, path []int, modify fn (model.ScoreUpdate) model.ScoreUpdate) model.ScoreUpdate {
	if path.len == 0 {
		return modify(update)
	}
	modified, _ := modify_nested_updates(update, fn [path, modify] (updates []model.ScoreUpdate) []model.ScoreUpdate {
		mut result := updates.clone()
		if path[0] < result.len {
			result[path[0]] = modify_nested_path(result[path[0]], path[1..], modify)
		}
		return result
	})
	return modified
}

// modify_at modifies the update at a nested index. This is the central method
// for updating nested score updates while importing.
fn (mut imp Importer) modify_at(ni NestedIndex, modify fn (model.ScoreUpdate) model.ScoreUpdate) {
	if ni.indices.len == 0 {
		return
	}
	mut voice := imp.voice()
	voice.updates[0] = modify_nested_path(voice.updates[0], ni.indices[1..], modify)
	imp.recount_beats()
}

fn get_nested_path(update model.ScoreUpdate, path []int) ?model.ScoreUpdate {
	if path.len == 0 {
		return update
	}
	mut nested := []model.ScoreUpdate{}
	match update {
		model.Repeat, model.OnRepetitions { nested = events_of(update.event) }
		model.Chord, model.EventSequence { nested = update.events.clone() }
		else { return none }
	}
	if path[0] >= nested.len {
		return none
	}
	return get_nested_path(nested[path[0]], path[1..])
}

// get_at returns the update at a nested index. Like Alda, this also recounts
// beats (it's implemented via modify_at there).
fn (mut imp Importer) get_at(ni NestedIndex) ?model.ScoreUpdate {
	if ni.indices.len == 0 {
		return none
	}
	found := get_nested_path(imp.voice().updates[0], ni.indices[1..])
	imp.recount_beats()
	return found
}

fn (mut imp Importer) set_at(ni NestedIndex, update model.ScoreUpdate) {
	imp.modify_at(ni, fn [update] (_ model.ScoreUpdate) model.ScoreUpdate {
		return update
	})
}

fn (mut imp Importer) valid(ni NestedIndex) bool {
	if ni.indices.len == 0 {
		return false
	}
	if _ := imp.get_at(ni) {
		return true
	}
	return false
}

fn (mut imp Importer) find_last(filter fn (model.ScoreUpdate) bool) (?model.ScoreUpdate, NestedIndex) {
	return find_last_recursive(imp.voice().updates, filter)
}

// find_last_from finds the last matching update before `start_index` in the
// flat updates.
fn (mut imp Importer) find_last_from(filter fn (model.ScoreUpdate) bool, start_index int) (?model.ScoreUpdate, NestedIndex) {
	flat := imp.flat_updates()
	found, ni := find_last_recursive(flat[..math.min(start_index, flat.len)], filter)
	if ni.indices.len > 0 {
		mut indices := [0]
		indices << ni.indices
		return found, NestedIndex{indices}
	}
	return found, ni
}

fn find_last_recursive(updates []model.ScoreUpdate, filter fn (model.ScoreUpdate) bool) (?model.ScoreUpdate, NestedIndex) {
	for i := updates.len - 1; i >= 0; i-- {
		if filter(updates[i]) {
			return updates[i], NestedIndex{[i]}
		}
		if nested := get_nested_updates(updates[i], false) {
			found, ni := find_last_recursive(nested, filter)
			if ni.indices.len > 0 {
				mut indices := [i]
				indices << ni.indices
				return found, NestedIndex{indices}
			}
		}
	}
	return none, NestedIndex{}
}

// find_last_with_octave finds the last update passing `filter`, tracking the
// octave (undoing octave changes) as it searches backwards.
fn find_last_with_octave(updates []model.ScoreUpdate, filter fn (model.ScoreUpdate, int) bool, initial int) (?model.ScoreUpdate, NestedIndex, int) {
	mut octave := initial
	for i := updates.len - 1; i >= 0; i-- {
		if filter(updates[i], octave) {
			return updates[i], NestedIndex{[i]}, octave
		}
		octave += octave_change(updates[i])
		if nested := get_nested_updates(updates[i], false) {
			found, ni, state := find_last_with_octave(nested, filter, octave)
			octave = state
			if ni.indices.len > 0 {
				mut indices := [i]
				indices << ni.indices
				return found, NestedIndex{indices}, octave
			}
		}
	}
	return none, NestedIndex{}, octave
}

// octave_change returns the reverse of an octave change (OctaveSets are
// ignored; they shouldn't occur between tied notes).
fn octave_change(update model.ScoreUpdate) int {
	if update is model.AttributeUpdate {
		pu := update.part_update
		if pu is model.OctaveUp {
			return -1
		}
		if pu is model.OctaveDown {
			return 1
		}
	}
	return 0
}

// import_musicxml translates a MusicXML document into Alda score updates. The
// document must be score-partwise.
pub fn import_musicxml(data string) ![]model.ScoreUpdate {
	doc := xml.XMLDocument.from_string(strip_doctype(data)) or {
		return error('Failed to read from input: ${err.msg()}.')
	}

	root := doc.root
	if root.name == 'score-timewise' {
		return error('Issue importing MusicXML: please convert input from score-timewise to score-partwise format (MusicXML provides an XSLT stylesheet to perform this conversion)')
	}
	if root.name != 'score-partwise' {
		return error('Issue importing MusicXML: could not find score-partwise root tag')
	}

	version := attr(root, 'version', '')
	if version != '3.1' {
		warn('MusicXML import supports version 3.1. Behaviour may be undefined with provided version ${version}.')
	}

	mut imp := &Importer{}
	handle(root, mut imp)
	return imp.generate_score_updates()
}
