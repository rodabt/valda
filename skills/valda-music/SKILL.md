---
name: valda-music
description: >
  Use when the user wants music written as Alda code and played or exported with valda.
  That covers backing tracks, jam tracks, play-alongs, accompaniment in a genre (blues, rock,
  pop, funk, jazz, bossa, reggae, country, metal, ballad), chord progressions, and practice
  material such as scales, modes, arpeggios, interval drills, rhythm drills and tempo-ramp
  exercises with a click. Writes a .alda score, validates it with valda, and exports MIDI/WAV.
  For detailed drum parts (rock/pop/metal grooves, fills, song-form drum arrangements), use
  the valda-drums skill instead or alongside.
---

# valda-music: backing tracks, accompaniment and exercises in Alda

valda is a self-contained Alda (text music language) interpreter with a built-in GM synth.
You write a `.alda` score, check it with `scripts/check.sh`, then the user plays it
(`valda play -f FILE`) or exports it (`valda export -f FILE -o out.mid`, or `-O wav -o out.wav`).

**Reference files (read the ones you need before writing):**

- `references/alda-syntax.md`: **read this every time.** It covers the syntax, the attributes, and the mistakes that keep recurring.
- `references/theory.md`: scale/mode formulas, chord spellings in Alda, voicing, and progressions.
- `references/genres.md`: per-genre tempo, instruments, bass/comping/drum figures with Alda code.
- `references/exercises.md`: count-ins, click tracks, scale/arpeggio/interval patterns, tempo ramps.
- `templates/backing-track.alda`: full-song structure to copy (sections, variables, markers, mix).
- `templates/scale-exercise.alda`: exercise structure to copy (count-in, click, drone, ramp).

**Running valda:** `scripts/check.sh` uses `$VALDA`, then `valda` on `PATH`, then the binary in this skill's repo.
If the user runs valda in Docker, prefix commands with `VALDA=<repo>/scripts/valda-docker.sh`, save the score under
the current directory (the container sees nothing outside it), and give the user `<repo>/scripts/valda-docker.sh play -f FILE`
instead of `valda play -f FILE`. If check.sh reports that valda isn't found, ask whether they built it or use Docker.
If `play` says no audio device was found, offer the WAV export instead.

## Workflow

1. **Brief.** Settle on: purpose (jam / practice / accompany a melody), genre/feel, key and mode, tempo,
   meter (default 4/4), length or form, instrumentation, and **which part the user plays**. Leave that part out
   of a backing track, or put it in as a guide part only if asked. If the user gave a genre and a key, fill in the
   rest from `genres.md` and say what you assumed. Don't interrogate them.
2. **Plan before you write.** Show a short chart: the sections with bar counts and the chords per bar. For example:
   ```
   intro 4 | verse 8: Am F C G ×2 | chorus 8: F C G Am ×2 | outro 4   @ 100 BPM ≈ 1:07
   ```
   Duration in seconds = bars × beats-per-bar × 60 / BPM.
3. **Write the score** (save it where the user asks, otherwise as `<name>.alda` in the working directory):
   - `(tempo! N)` at the top. Always the global `!` form.
   - **One variable per section per instrument** (`verseBass`, `chorusKeys`), each starting with an explicit
     `oN` and a duration, and returning to its starting octave by the end.
   - `%marker` per section in the **first** part only.
   - Parts in this order: drums, bass, harmony, pad/extras. Set `(track-vol)`/`(pan)` at the top of each part.
   - Every part must add up to the **same number of bars**. Count them per section.
   - Put `|` bar lines everywhere, and add a header comment with the form/chord chart.
4. **Check:** `scripts/check.sh FILE.alda`. It fails with valda's `line:col` error, or prints the note count,
   the length, the per-part counts and the marker times. Make sure the length and marker times match the plan
   (a marker at the wrong time means a section is miscounted). Fix and re-run until it passes.
5. **Deliver:** tell the user the play command (`valda play -f FILE`, or `--from chorus1` to audition a section)
   and offer exports: `scripts/check.sh FILE.alda --midi out.mid --wav out.wav`. MIDI imports into any DAW.

## Musical defaults

- **Bass** `o1`–`o2`, **comping** `o3`–`o4` with voice-led chords (move the fewest notes), **pad** `o4`
  sustained with `(quant 100)`. Keep comping out of the bass register.
- **Leave space for the user.** Comping should be rhythmic and mid-register, without a busy melody on top of their part.
  If they solo on guitar, comp on keys (and the reverse).
- **Variety by section:** verse sparser (half notes, closed hats); chorus fuller (8ths, ride/open hats,
  pad up a bit). End sections with a turnaround or a drum fill into the next.
- **Endings:** a final chord held 1–2 bars (`g1~1/b/>d<`) with a crash. Don't just stop.
- Drums for a backing track: use the simple patterns in `genres.md`. When the user cares about the drums
  (fills, variations, a specific style), switch to the **valda-drums** skill for that part.
- Swing/shuffle: no swing attribute. Write triplets (`c6 d12`).

## Exercises

Default to: a 1-bar count-in, a click under the whole exercise, the pattern ascending then descending, ending on the root.
Use the user's instrument (and its range), state the tempo, and offer a tempo ramp version (`(tempo! …)` steps,
one bar of count-in before each). When the user names a scale or mode, spell it from `theory.md` and
double-check every accidental. Use `(key-sig '(…))` for diatonic patterns.

## Common mistakes

- A run crosses B→C without `>`, or a variable doesn't return to its starting octave and the repeats drift.
- Sticky duration after a fast figure. Restate the duration at the start of the next phrase.
- Chord timing: the next event starts after the chord's **shortest** note.
- `(tempo …)` without `!` affects only one part.
- Variable names need two leading letters, and a variable that contains voices must be bracketed `[V1: … V0:]`.
- Octave, duration and `(vol)` leak out of voices after `V0:`. Start each voice, and the code after `V0:`, with explicit values.
- `guitar:` is nylon. For steel or electric, name the instrument explicitly.
