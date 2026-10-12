# Theory reference

Semitone formulas count up from the root. To spell a scale in Alda, walk the letters in order (one letter per
degree for 7-note scales) and add `+`/`-` so each pitch hits the formula. You can also set a key signature with
`(key-sig '(e minor))` and write plain letters. Prefer key signatures for diatonic material and explicit
accidentals for chromatic or blues notes.

## Scales and modes

| Scale | Semitones | Degrees | Example (root C) |
|---|---|---|---|
| Major / ionian | 0 2 4 5 7 9 11 | 1 2 3 4 5 6 7 | c d e f g a b |
| Natural minor / aeolian | 0 2 3 5 7 8 10 | 1 2 b3 4 5 b6 b7 | c d e- f g a- b- |
| Harmonic minor | 0 2 3 5 7 8 11 | 1 2 b3 4 5 b6 7 | c d e- f g a- b |
| Melodic minor (asc.) | 0 2 3 5 7 9 11 | 1 2 b3 4 5 6 7 | c d e- f g a b |
| Dorian | 0 2 3 5 7 9 10 | 1 2 b3 4 5 6 b7 | c d e- f g a b- |
| Phrygian | 0 1 3 5 7 8 10 | 1 b2 b3 4 5 b6 b7 | c d- e- f g a- b- |
| Lydian | 0 2 4 6 7 9 11 | 1 2 3 #4 5 6 7 | c d e f+ g a b |
| Mixolydian | 0 2 4 5 7 9 10 | 1 2 3 4 5 6 b7 | c d e f g a b- |
| Locrian | 0 1 3 5 6 8 10 | 1 b2 b3 4 b5 b6 b7 | c d- e- f g- a- b- |
| Phrygian dominant | 0 1 4 5 7 8 10 | 1 b2 3 4 5 b6 b7 | c d- e f g a- b- |
| Major pentatonic | 0 2 4 7 9 | 1 2 3 5 6 | c d e g a |
| Minor pentatonic | 0 3 5 7 10 | 1 b3 4 5 b7 | c e- f g b- |
| Blues (minor) | 0 3 5 6 7 10 | 1 b3 4 b5 5 b7 | c e- f g- g b- |
| Major blues | 0 2 3 4 7 9 | 1 2 b3 3 5 6 | c d e- e g a |
| Whole tone | 0 2 4 6 8 10 | | c d e f+ g+ a+ |
| Diminished (H-W) | 0 1 3 4 6 7 9 10 | | c d- e- e f+ g a b- |
| Chromatic | all 12 | | c c+ d d+ e f f+ g g+ a a+ b |

Mode ↔ parent major: dorian = major from the 2nd degree, phrygian = from the 3rd, lydian = 4th,
mixolydian = 5th, aeolian = 6th, locrian = 7th.

## Chord qualities

| Chord | Symbol | Semitones | On C (Alda) |
|---|---|---|---|
| Major | C | 0 4 7 | `c/e/g` |
| Minor | Cm | 0 3 7 | `c/e-/g` |
| Diminished | Cdim | 0 3 6 | `c/e-/g-` |
| Augmented | Caug | 0 4 8 | `c/e/g+` |
| Sus2 / Sus4 | Csus2 / Csus4 | 0 2 7 / 0 5 7 | `c/d/g`, `c/f/g` |
| Power chord | C5 | 0 7 (12) | `c/g/>c<` |
| Major 7 | Cmaj7 | 0 4 7 11 | `c/e/g/b` |
| Dominant 7 | C7 | 0 4 7 10 | `c/e/g/b-` |
| Minor 7 | Cm7 | 0 3 7 10 | `c/e-/g/b-` |
| Half-dim | Cm7b5 | 0 3 6 10 | `c/e-/g-/b-` |
| Dim 7 | Cdim7 | 0 3 6 9 | `c/e-/g-/a` |
| 6 / m6 | C6 / Cm6 | 0 4 7 9 / 0 3 7 9 | `c/e/g/a` |
| Add9 | Cadd9 | 0 4 7 14 | `c/e/g/>d<` |
| Dominant 9 | C9 | 0 4 7 10 14 | `c/e/g/b-/>d<` |

Diatonic triads in major: I ii iii IV V vi vii°. In natural minor: i ii° III iv v VI VII. Harmonic minor
makes V major (and V7), which is the usual choice in minor-key cadences.

## Voicing for backing tracks

- Keep the **bass** in `o1`–`o2` (bass instruments sound an octave lower in GM, so `o2` is safe), the
  **comping** chords in `o3`–`o4`, and **pads** in `o4`, spread out. Avoid tight triads below `o3 c`. They sound muddy.
- **Voice-lead** between chords: keep common tones and move the other voices by step. Don't jump every chord to root position.
  C → Am → F → G: `o4 c/e/g` → `c/e/a` → `c/f/a` → `< b/>d/g<`.
- Guitar power chords: root and fifth (plus the octave) in `o2`/`o3`. Pair them with `(quant 50)` for chugs and `(quant 95)` for ringing chords.
- Jazz comping: shell voicings (3rd and 7th, plus the root in the bass part). Cmaj7 = `e/b`, C7 = `e/b-`, Cm7 = `e-/b-`.

## Common progressions

| Style | Progression | Example |
|---|---|---|
| Pop "axis" | I–V–vi–IV | C G Am F |
| 50s / doo-wop | I–vi–IV–V | C Am F G |
| Pop minor start | vi–IV–I–V | Am F C G |
| 12-bar blues | I7 I7 I7 I7 / IV7 IV7 I7 I7 / V7 IV7 I7 V7 | A7 D7 E7 (quick-change: IV7 in bar 2) |
| Minor blues | i i i i / iv iv i i / VI7 V7 i V7 | Am Dm F7 E7 |
| Jazz ii–V–I | ii7–V7–Imaj7 | Dm7 G7 Cmaj7 |
| Rhythm-changes A | I–vi–ii–V | Bb Gm Cm F |
| Andalusian | i–VII–VI–V | Am G F E |
| Epic / metal | i–VI–III–VII | Am F C G |
| Metal (phrygian) | i–bII | E5 F5, chromatic chugs on E |
| Rock mixolydian | I–bVII–IV–I | D C G D |
| Canon | I–V–vi–iii–IV–I–IV–V | D A Bm F#m G D G A |
| Bossa / jazz | Imaj7–VI7–ii7–V7 | Cmaj7 A7 Dm7 G7 |
| Funk vamp | i7 (one chord), or i7–IV7 | Em7 A7 |
| Reggae | I–IV, I–V | C F, C G |
