---
name: valda-drums
description: >
  Use when the user wants drum parts written as Alda code for valda. That covers drum
  beats, grooves, fills and full drum tracks for rock, pop and metal (and relatives such as
  hard rock, punk, pop-punk, thrash, metalcore, disco/dance-pop), arranged over a song form
  with intro, verse, pre-chorus, chorus, bridge, breakdown, solo and outro sections,
  variations, fills, crashes, builds, stops and endings. Also covers drum practice loops and
  adding drums to an existing .alda score. Validates with valda and exports MIDI/WAV.
  For non-drum instruments (bass, chords, backing tracks, scales), use valda-music.
---

# valda-drums: rock, pop and metal drum parts in Alda

The output is a `.alda` score on the GM drum kit (`midi-percussion`), validated with `scripts/check.sh` and
played with `valda play -f FILE` or exported (`--midi`/`--wav`). MIDI drops straight into a DAW drum track
(channel 10, GM mapping).

**Reference files:**

- `references/gm-drum-map.md`: which Alda pitch is which drum (kick `o2 c`, snare `o2 d`, hats `o2 f+`/`a+`…).
- `references/grooves.md`: 17 one-bar grooves (rock, pop, metal) as tab + code. **Start from these.**
- `references/fills.md`: fills (1-beat to 1-bar, toms, triplets, linear, metal), rolls, builds, stops, endings.
- `references/song-structure.md`: forms per style, what changes per section, phrasing, **the crash layer**, count-ins.
- `templates/song-drums.alda`: a complete 64-bar rock arrangement. Copy its layout.
- valda-music's `references/alda-syntax.md` has the general Alda rules if you need them.

## Notation convention (always follow it)

1. **Every bar is a variable in limb voices**, with a tab comment above it:
   ```
   #     1 & 2 & 3 & 4 &
   # HH  x x x x x x x x
   # SN  . . x . . . x .
   # BD  x . . . x x . .
   verseA = [
     V1: (vol 70) o2 f+8 f+ f+ f+ f+ f+ f+ f+
     V2: r8 r (vol 90) o2 d r r r d r
     V3: (vol 92) o2 c8 r r r c c r r
     V0:
   ]
   ```
   V1 = hands on cymbals (or a timekeeping tom), V2 = snare/toms, V3 = kick. Write **every grid step** (a note or `r`)
   on a fixed grid: 8ths (`8`), 16ths (`16`) or 8th-triplets (`12`). Then the code reads like the tab, and every
   voice adds up to exactly one bar.
2. **Each voice's first note sets `(vol N)` and `oN` explicitly.** Voices leak octave, duration and volume after `V0:`.
   Volumes: cymbals 70 (accent 90), snare 90 (accent 100, ghost 28), kick 92.
3. **Never nest voice groups.** Don't put a groove variable inside a `V1:` line, because the timing breaks. Sequence bars
   instead: `verseA*3 verseB`.
4. **Crashes go in a second part** (`midi-percussion "crashes":`) that jumps to `@markers` placed in the kit part.
   See the crash layer in `song-structure.md`. The crash part must come after the kit part.
5. Section dynamics come from the grooves themselves: softer `(vol)` numbers in verse grooves, accents and ride/crash in choruses.
   Both drum parts share MIDI channel 10, so `(track-vol)` is channel-wide. Leave it at the default, or set the **same** value at
   the top of both parts. Never change it mid-song.

## Workflow

1. **Brief:** style, tempo, feel (straight/shuffle/half-time), and form with bar counts. If the user gives only a style, propose a
   form from `song-structure.md`. Ask only for what you can't sensibly default.
2. **Arrangement table first.** Show the user a table (section · bars · groove · phrase-end variation · fill into next) like
   the header of `templates/song-drums.alda`, with the total length (bars × 4 × 60 / BPM s).
3. **Write the grooves** by picking from `grooves.md`, adapting a tab when the style needs it (change the tab first, then the
   code), and making variation bars (`verseB`) by changing one or two hits.
4. **Write the kit part:** one `%marker` per section and per phrase that needs a crash (`%chorus1b`), each line
   adding up to that section's bar count. Then the **crash part:** `@marker c+1` for each crash.
5. **Check:** `scripts/check.sh FILE.alda`. Compare the marker times it prints with the table (each marker should be at
   bar × 4 × 60 / BPM seconds). A wrong time means a miscounted section. Fix it and re-run.
6. **Deliver:** the file path, `valda play -f FILE` (or `--from chorus1`), and an offer of
   `scripts/check.sh FILE --midi drums.mid --wav drums.wav`.

## Adding drums to an existing score

Read the score first: its tempo, form, and existing `%markers`. Put the kit part **first**, so its markers drive the score,
or reuse the score's markers with `@marker` at the start of each section of the kit part. Match the kick to the bass rhythm
and the hits to the band's accents. Keep the total bar count identical to the other parts.

## Style quick picks

- **Rock:** `rock8` verses, ride or open-hat choruses, `fillToms`/`fillTriplets` into choruses, `halfTime` bridge.
- **Pop:** `balladStick` or `popSync` verse, `fourFloor` or `disco` chorus, a `buildUp` across the pre-chorus, clap on the snare.
- **Punk / pop-punk:** `punkSkank` everywhere (hats in verses, ride in choruses), half-time bridge, `fillStop` before the last chorus.
- **Metal:** `gallop` or `thrashSkank` verses, `doubleKick` choruses, `blastTrad` for extreme sections, `breakdown` with china,
  and `fillMetal` (toms over double kick). The kick should mirror the guitar riff. Ask for the riff rhythm if it matters.

## Common mistakes

- A voice that is one step short or long. The bar still parses but drifts. Count the steps (8 or 16 per bar, 12 for triplets).
- Forgetting `o3` for crash/ride/high toms, or `o2` for the kick and snare, after a cymbal.
- Toms descending from `o3 c` to `o2 b` need an explicit `o2`.
- A fill at the end of every 2 bars. Mostly fill only at phrase ends (4/8 bars).
- No crash after a fill or at a section start, or a crash part placed before the kit part (its markers aren't defined yet).
