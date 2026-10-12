# Alda syntax for valda: cheat sheet and gotchas

Everything here was checked against `valda parse`. valda matches Alda 2.4.7.

## Notes, rests, durations

| Write | Meaning |
|---|---|
| `c d e f g a b` | note letters |
| `c+` `c-` `c_` `c++` | sharp, flat, natural (overrides key sig), double sharp |
| `c4` `c8` `c16` `c1` `c2` | quarter, eighth, sixteenth, whole, half |
| `c4.` `c4..` | dotted, double dotted |
| `c6` `c12` `c24` | quarter-triplet, eighth-triplet, sixteenth-triplet (any denominator works) |
| `c1~1` `c4~16` | tied durations (adds them) |
| `c~d~e` | slur (legato, no gap between notes) |
| `c500ms` `c2s` | absolute durations |
| `r4` `r1*4` | rests; `*n` repeats any event: `r1*4` is 4 bars of rest in 4/4 |
| `\|` | bar line. Ignored by the parser, but **always** put them in for readability |
| `# comment` | comment to end of line |

**Duration is sticky.** A note with no number reuses the previous duration: `c8 d e f` is four eighths.
**Octave is sticky.** `o4` sets it (`o4 c` is middle C, MIDI 60). `>` goes up an octave, `<` goes down, and both stay in effect afterwards. A scale run that crosses B→C needs a `>`: `o4 a b > c d`.

## Chords

`c/e/g` plays together. Each note can have its own duration. **The next event starts after the
shortest note in the chord** (`c1/e2/g4 d` puts `d` on beat 2). Octave changes work inside a chord:
`o3 c1/e/g/>c<`. Leave the octave where you found it by closing with `<`, or you'll drift upward.
Tie a chord across bars on its **first** note: `d1~1/a` holds both notes for 2 bars, while `d1/a~1` is a parse error.

## Parts and instruments

```alda
piano: c d e f
electric-bass-finger: o2 c4 c g c
midi-acoustic-guitar-steel "rhythm": o3 c1/e/g
```

- `name:` starts (or switches to) a part. Use `instrument "alias":` to have two parts on the same instrument.
- `piano/violin:` sends the same notes to both parts (unison).
- The instrument list is `valda instruments`. Useful names: `piano`, `midi-electric-piano-1`,
  `midi-rock-organ`, `midi-drawbar-organ`, `midi-acoustic-guitar-steel`, `guitar` (= nylon!),
  `midi-electric-guitar-clean`, `midi-electric-guitar-jazz`, `midi-electric-guitar-overdrive`,
  `midi-electric-guitar-distorted`, `midi-electric-guitar-palm-muted`, `acoustic-bass` (upright),
  `electric-bass` (finger), `midi-electric-bass-pick`, `midi-fretless-bass`, `midi-synth-bass-1`,
  `midi-string-ensemble-1`, `midi-synth-pad-warm`, `midi-synth-pad-polysynth`, `midi-brass-section`,
  `alto-sax`, `tenor-sax`, `trumpet`, `trombone`, `flute`, `vibraphone`, `marimba`, `midi-percussion`.
- `midi-percussion:` (alias `percussion:`) is the GM drum kit on MIDI channel 10. There, each pitch is
  a drum (see the valda-drums skill's `gm-drum-map.md`). Kick `o2 c`, snare `o2 d`,
  closed hat `o2 f+`, side stick `o2 c+`, high woodblock `o5 e`.
- valda assigns MIDI channels automatically. There are 15 melodic channels plus the drum channel.

## Voices (polyphony inside one part)

```alda
piano:
  V1: o5 e4 d c2
  V2: o4 c2 < g2
  V0: o4 c1/e/g
```

`V1:` `V2:` … run in parallel from the same start point. `V0:` ends the voices, and the part then
continues from the end of the **longest** voice.

**Attribute leakage:** every voice starts from the part's state at the voice group. After `V0:`, though, the
part continues with **one voice's** attributes: octave, duration, `(vol)`. (It's the voice that ends last, and the
highest-numbered one on a tie.) A `(vol 25)` ghost note in a voice can therefore make everything after it quiet. **Start every voice with an explicit `oN`, a duration and, if
the score uses dynamics anywhere, a `(vol N)`.**

## Variables

```alda
verseChords = o3 a1/>c/e< | f/a/>c< | c/e/g | g/b/>d<
piano: verseChords*2
```

- Names need **two letters to start** (`ab`, `riff1`, `verseA`). `b`, `g`, `x1` are errors.
- A variable definition is one line, or a bracketed `[ ... ]` sequence that spans lines.
- Voices inside a variable must be bracketed: `fill = [V1: ... V2: ... V0:]`.
- Variables are expanded where they're used, so octave/duration state carries in and out. **Start every variable
  with an explicit `oN` and duration.** That way it doesn't depend on what came before.

## Repeats and alternate endings

```alda
piano: [c4 d e f]*2
piano: [ c4 d e f | [g2 g]'1-3 [c1]'4 ]*4
```

`'1-3` / `'4` / `'1,3` mark which passes play that bracket.

## Attributes (Lisp-style, in parentheses)

| Attribute | Notes |
|---|---|
| `(tempo! 120)` | **global** tempo, for all parts. Use this at the top of a score |
| `(tempo 120)` | tempo for **this part only**. Other parts keep their own tempo and drift out of sync. Avoid it in multi-part scores |
| `(key-sig '(a minor))` `(key-sig '(d dorian))` `(key-sig "f+ c+")` | key signature for this part. Modes: ionian dorian phrygian lydian mixolydian aeolian locrian, major, minor |
| `(transpose -12)` | semitones |
| `(vol 70)` | note volume 0–100 (velocity). Sticky |
| `(pp) (p) (mp) (mf) (f) (ff) (fff)` | dynamic shortcuts that set `vol` |
| `(track-vol 80)` | channel volume (CC 7/11). Use it to balance parts in a mix |
| `(pan 20)` | 0 = left, 50 = center, 100 = right |
| `(quant 90)` | % of the duration that sounds. Default 90. Use ~50 for staccato/stabs and 99–100 for legato pads/bass |

The `!` form (`(vol! 60)`, `(quant! 80)`) sets the attribute for every part. There's **no swing
attribute**. Write swing as triplets instead (`c6 d12` = swung eighth pair).

## Markers

```alda
piano:         %verse c1 | d | %chorus e | f
electric-bass: @verse o2 c1 | d | @chorus e | f
```

`%name` defines a marker at the current time. `@name` jumps a part to it. Use one marker per section,
in the first part. Then `valda play -f song.alda --from chorus` (or `-F chorus -T bridge`) auditions a
section, and `@marker` in later parts realigns them if a bar count drifts.

## Common mistakes

1. Forgetting `>` when a run crosses B→C. The line falls an octave.
2. A missing or extra `<`/`>` inside a repeated variable. Every repetition drifts an octave.
3. Leaving the duration sticky after a fill (`c32`) and getting a whole verse of 32nds. Restate the duration.
4. `(tempo …)` in one part only. That part speeds up alone.
5. Parts with different bar counts. Count the bars of each section in every part, or realign with `@markers`.
6. Single-letter variable names.
7. Writing `guitar:` when you want steel-string or electric. `guitar` is nylon.
