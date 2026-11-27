# Cue structure: arcs, timing, themes and endings

A cue is shaped by **energy over time**, not verse/chorus. Plan the arc first, then fill each section with texture.

## Timing math

- Seconds per bar = beats-per-bar × 60 / BPM. Bars for a length = seconds × BPM / (60 × beats-per-bar).
- A hit at T seconds lands on bar `T × BPM / (60 × beats) + 1` (1-based). Pick a BPM that puts every hit on (or very
  near) a downbeat. If a hit falls between bars, (a) nudge the BPM, (b) add one bar of 2/4 or 3/4 (a shorter bar)
  before it, or (c) put a `(tempo! N)` change in the section before it. `(tempo! …)` mid-score stays in sync across all parts.
- Ritardando: step the tempo down over the last 2–4 bars, e.g. `(tempo! 80) … | (tempo! 74) … | (tempo! 66) …`.
  Accelerando (horror chases, builds) is the reverse.
- **A tied or long note keeps the tempo it started in.** Over a tempo change, split held notes at the change
  (`d1~1 | d1 | d1`, not `d1~1~1~1`), or that part ends early or late. `check.sh` won't tell you, but its length and
  the other parts' marker times will.

| Length | 60 BPM 4/4 | 72 | 90 | 100 | 120 | 140 |
|---|---|---|---|---|---|---|
| 30 s | 7.5 bars | 9 | 11.25 | 12.5 | 15 | 17.5 |
| 60 s | 15 | 18 | 22.5 | 25 | 30 | 35 |
| 90 s | 22.5 | 27 | 33.75 | 37.5 | 45 | 52.5 |
| 120 s | 30 | 36 | 45 | 50 | 60 | 70 |

Round to whole phrases (4/8 bars) and nudge BPM: 60 s at 128 BPM = 32 bars exactly, at 96 BPM = 24 bars.

## Arcs (pick one; the brief's "arc" answer maps here)

| Arc | Shape | Sections (share of the length) | Fits |
|---|---|---|---|
| **Swell** | low → high → low | intro 25% · rise 35% · peak 20% · release 20% | drama, romance, fantasy, sci-fi reveals |
| **Build to hit** | steady rise, ends at max | groove 30% · build 40% · climax 30%, end on a hit | action, trailers, boss intros |
| **Trailer (3 acts)** | rise → hit → bigger rise → hit → tail | act 1 (sparse, theme hint) 30% · act 2 (pulse + layers) 35% · act 3 (full, theme loud) 25% · tail 10% | epic, heroic, sci-fi |
| **Slow burn + stinger** | flat, creeping → silence → spike | drone 40% · creep (ostinato speeds up) 40% · silence 1–2 beats · stinger + decay 15% | horror, thriller |
| **Tension waves** | rise, partial release, higher rise | wave 1 · drop · wave 2 (a semitone up) · cut-off | thriller, chase, suspense |
| **Static / bed** | one level, slow change | 8- or 16-bar blocks, small variations | underscore under dialogue, ambience, game exploration |
| **Seamless loop** | no beginning or end | A (8–16 bars) · B · back to A, with the last bar leading into the first | game music, menus, background loops |

### Building energy (use 3–4 at once)

Add layers every 4–8 bars · shorter note values (half → quarter → 8th → 16th ostinato) · higher register (theme up
an octave) · louder `(vol)` steps · faster harmonic rhythm (one chord per bar → two) · a pedal under changing chords ·
percussion density (taiko on 1 → on 1 and 3 → syncopated) · semitone shifts upward · a reverse cymbal or timpani roll into each new section.

### Releasing energy

Drop percussion first, then brass, then the high strings. Lengthen note values, step `(vol)` down and slow the tempo slightly.
Leave the theme fragment in one solo instrument.

## Themes and leitmotifs

A theme is **3–6 notes with a memorable rhythm and contour**, usually 2 or 4 bars long. Write it once, as a variable,
and reuse it transformed instead of writing new tunes:

| Transformation | Effect | How |
|---|---|---|
| Major ↔ minor | triumph ↔ tragedy | lower the 3rd/6th/7th |
| Augmentation | grief, awe, an ending | double every duration |
| Diminution / fragment | urgency, chase | first 3 notes, faster, sequenced up |
| Reorchestration | new character | solo oboe (fragile) → horns (noble) → full tutti (victory) |
| Register | intimacy ↔ grandeur | `o3` cello vs. `o5` violins + `o4` trumpets |
| Reharmonization | changes the meaning | the same melody note over a mediant chord instead of the tonic |

```alda
# One motif, three characters: hopeful (flute), tragic (minor, augmented, cello), triumphant (horns + trumpet, tutti)
(tempo! 90)
midi-flute:
  (vol 70) o5 d4 a4 g8 f+8 e4 | d1 | r1*4 | r1*2
midi-cello:
  (vol 70) (quant 100) r1*2 | o3 d2 a2 | g4 f4 e2 | d1~1 | r1*2
midi-french-horn:
  (vol 92) r1*6 | o4 d4 a4 g8 f+8 e4 | d1
midi-trumpet:
  (vol 88) r1*6 | o4 d4 a4 g8 f+8 e4 | d1
```

## Hit points (scoring to picture or game events)

Collect them as `time → event` in the brief (`0:42 door slams`, `1:10 hero appears`). Put a `%marker` at each
one, put the hit on a downbeat (see the timing math), and score *into* it: a 1–2 bar build before it (roll, reverse
cymbal, rising line), the hit itself (low brass + timpani + crash + the root in the bass), then a change of texture after it.
Check that `scripts/check.sh` prints each marker at the hit time, ±0.1 s.

## Endings

| Ending | Use for | Recipe |
|---|---|---|
| **Resolve** | drama, romance, fantasy | final chord held 2 bars (`~1`), add the 9th or a Picardy 3rd for warmth, decay by dropping parts |
| **Button** | heroic, comedy | after the last phrase, one short tutti chord on the downbeat (`quant 40`), then rests |
| **Big hit + tail** | epic, trailer | ff hit on all parts + crash + timpani, then a 1–2 bar low drone or a single solo instrument |
| **Stinger** | horror, thriller | 1–2 beats of total silence, then an ff cluster in every register (`o1`–`o6`) + low piano + crash, let it ring |
| **Fade** | underscore, sci-fi | repeat the last 2–4 bars, stepping `(vol)` down 10–15 per bar, dropping parts out from the top |
| **Open / unresolved** | mystery, elegy, cliffhanger | end on iv, V, mM7, a sus chord or a single held note |
| **Seamless loop** | games | the last bar is the same harmony as bar 0 (or its V), with no ending gesture. Test with `valda play` twice in a row |
