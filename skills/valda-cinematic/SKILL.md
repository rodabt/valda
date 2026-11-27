---
name: valda-cinematic
description: >
  Use when the user wants cinematic, orchestral or soundtrack music written as Alda code for
  valda: film, trailer, TV or game cues, underscore, scene music, leitmotifs and themes in
  moods such as epic/action, heroic adventure, fantasy, drama/emotional, horror, thriller/
  suspense, sci-fi/space, romance, mystery/noir, whimsical/comedy and war/elegy. Covers
  orchestration (strings, brass, woodwinds, timpani, choir, harp, hybrid synths/taiko),
  dramatic arcs (builds, swells, climaxes, stingers, risers), scoring to hit points, and
  loops for games. Asks for missing details (mood, length, purpose, arc) before writing.
  Validates with valda and exports MIDI/WAV. For band backing tracks use valda-music; for
  rock/pop/metal drum kits use valda-drums.
---

# valda-cinematic: film and orchestral cues in Alda

You write a `.alda` score for valda's built-in GM orchestra, check it with `scripts/check.sh`, check its dynamic arc
with `scripts/levels.sh`, then the user plays it (`valda play -f FILE`) or exports it (MIDI for a DAW, or WAV).

**Reference files (read the ones you need before writing):**

- valda-music's `references/alda-syntax.md`: **read this every time.** It covers the syntax and the mistakes that keep recurring.
- `references/genres.md`: per-genre defaults (BPM, key/mode, ensemble, arc) and one validated texture per genre. **Start here.**
- `references/harmony.md`: cinematic progressions and moves (mediants, Lydian, minor iv, pedals, clusters), spelled in Alda.
- `references/orchestration.md`: GM instrument names and ranges, the **15-channel budget**, seating/mix, swells, rolls, risers.
- `references/cue-structure.md`: arcs, timing math, hit points, theme transformations, endings.
- `templates/epic-cue.alda` (hybrid trailer arc), `templates/horror-cue.alda` (slow burn + stinger),
  `templates/drama-cue.alda` (piano + strings swell, ritardando). Copy their layout.

**Running valda:** `scripts/check.sh` uses `$VALDA`, then `valda` on `PATH`, then the binary in this skill's repo.
If the user runs valda in Docker, prefix commands with `VALDA=<repo>/scripts/valda-docker.sh`, save the score under
the current directory (the container sees nothing outside it), and give the user `<repo>/scripts/valda-docker.sh play -f FILE`
instead of `valda play -f FILE`. If check.sh reports that valda isn't found, ask whether they built it or use Docker.
If `play` says no audio device was found, offer the WAV export instead.

## 1. Brief gate: ask before writing

A cue needs four things. Take them from the request when they're there:

| Required | Examples |
|---|---|
| **Mood / genre** | epic, horror, tender drama, whimsical… (one of the genres in `genres.md`, or a blend) |
| **Length** | seconds or minutes (30 s sting, 1 min cue, 2–3 min piece) |
| **Purpose** | standalone piece · underscore under dialogue · trailer · game loop · scene with hit points |
| **Arc** | static bed · swell · build to a climax · trailer rise-hit-tail · slow burn + stinger · tension waves · seamless loop |

**If any required item is missing or vague** ("something scary", "music for my game"), ask with **AskUserQuestion,
one round, at most 4 questions**, and offer options fitted to the genre (e.g. for horror: arc = "slow creep + stinger" /
"constant dread bed" / "chase that speeds up"). Add a 4th question only if it really changes the score: ensemble
(full orchestra / intimate chamber / hybrid with synths and taiko), lead instrument, ending, or hit points with timestamps.
Never ask about something the user already said, and don't ask a second round. Default the rest from `genres.md`
(tempo, key, ensemble, ending) and **state your assumptions** in one line.

If everything required is present (e.g. "90-second epic battle cue in D minor, building to a climax at 1:00"), don't ask:
go straight to the cue sheet.

If the user names a film or composer ("like Interstellar", "Zimmer-style"), take the **style** (instrumentation, harmony,
texture, arc) from `genres.md`, and write an original theme. **Never quote or paraphrase a recognizable existing theme.**
Say so if they ask for one.

## 2. Cue sheet (show it before writing)

Pick a BPM that makes the length a whole number of 4/8-bar phrases and puts every hit point on a downbeat (`cue-structure.md`).
Show a table like the header of the templates:

```
| marker | bars  | time | harmony            | texture / orchestration           | dyn   |
| intro  | 1-8   | 0:00 | Dm pedal           | low drone, pad, horn hint of theme | pp-p  |
| build  | 9-16  | 0:15 | Dm Bb F C x2       | 16th string ostinato, taiko         | mp    |
...
128 BPM, 40 bars = 1:15 · 12 melodic parts + percussion
```

Seconds per bar = beats × 60 / BPM. List the parts and check that there are **≤ 15 melodic parts** (`orchestration.md`).

## 3. Write the score

Save it where the user asks, otherwise as `<name>.alda` in the working directory. Put the cue sheet in a header comment.

- `(tempo! N)` at the top. A ritardando or tempo change is a `(tempo! N)` inside the **first** part (it's global and stays in sync).
- **Theme first:** write the leitmotif as variables (`themeA`, `themeB`) and reuse it transformed: `(transpose 12)` for
  violins 8va, `(transpose -12)` for cellos, a minor or augmented version for tragedy (`cue-structure.md`).
- One variable per texture or chord bar (`ostDm`, `padLoop`), each starting with an explicit `oN` and a duration.
- Parts in score order: woodwinds, brass, percussion, choir/synth/harp, strings. `%markers` go in the **first** part.
  Set `(track-vol)`, `(pan)` and `(quant)` at the top of each part (`orchestration.md` seating table). Use `(vol)` for dynamics.
- Every part adds up to the **same number of bars**. Write `r1*N` for tacet sections, and comment each section line.
- **Dynamics are the drama.** Crescendo = a stepped `(vol)` on re-articulated notes (tremolo, ostinato, rolls) + adding
  instruments + a riser. A held note can't get louder. Climax = the theme in octaves, the full choir, a crash, and the timpani on the root.
- Alias names: letters, digits and `-` only (`midi-string-ensemble-1 "low-strings":`). No spaces.

## 4. Check and deliver

1. `scripts/check.sh FILE.alda`: it must pass, the length must match the cue sheet, and each marker must sit at its planned time (±0.1 s).
   A marker in the wrong place means a miscounted section.
2. `scripts/levels.sh FILE.alda`: the per-section loudness should follow the arc (the climax is the loudest section,
   intro and tail are quieter, and a stinger peaks after the silence). **No clipping.** If it clips, scale every `(track-vol)` by 0.8.
3. Tell the user the file, the cue sheet summary, `valda play -f FILE` (or `--from climax` to audition), and offer
   `scripts/check.sh FILE --midi cue.mid --wav cue.wav`. Suggest `valda export -M 1` for a multitrack MIDI (one track per section) for a DAW.

## Genre quick picks

- **Epic:** i–VI–III–VII, 16th string ostinato, horns + low strings theme, taiko, choir at the climax, trailer arc.
- **Heroic:** a major fanfare with a leap, I–♭VII–IV and the I–♭VI–♭VII–I cadence, march snare, brass tutti restatement.
- **Fantasy:** Lydian ♯4, harp/celesta arpeggios, flute or violin melody, choir oohs, planing triads.
- **Drama:** piano broken chords, cello then violins on the theme, minor iv, suspensions, a pedal, a ritardando ending.
- **Horror:** no key, semitone clusters, a low E–F ostinato getting faster, a corrupted music box, silence, then a stinger.
- **Thriller:** a 16th pulse on one low note rising by semitones, mM7 brass stabs, a timpani heartbeat.
- **Sci-fi:** chromatic mediants with a held common tone, synth pad + saw arps, choir oohs.
- **Romance:** 3/4, harp arps, solo violin/oboe, sus-and-resolve, the octave-doubled final phrase.
- **Noir:** line cliché, muted trumpet, upright bass, unresolved mM7. **Whimsical:** pizz oom-pah, bassoon staccato, a button ending.
- **Elegy:** lament bass, string chorale, solo horn, distant snare roll, an open ending.

## Common mistakes

- More than 15 melodic parts sounding at once means "No MIDI channel available". Merge sections into ensembles, or use voices for divisi.
- Thirds and dense chords below `o3` turn to mud. Use roots/fifths low, and thirds in `o3`–`o4`.
- **A tied note across a `(tempo! …)` change keeps its starting tempo**, so that part drifts. Split held notes at each tempo change.
- A crescendo written on one long note does nothing, and `(track-vol)` changes mid-part don't swell either. Re-articulate with a stepped `(vol)`.
- A sticky `(vol 100)` after a stinger or climax leaves everything after it loud. Restate `(vol)` at each section start.
- Octave, duration and `(vol)` leak out of voices and variables. Start every variable/voice with explicit `oN`, a duration and a `(vol)`.
- Everything doubled everywhere, all the time. Save the tutti for the climax so it means something. Keep intros thin.
- A reverse cymbal started at the downbeat. It peaks ~1.5 s after its start, so start it `1.5 × BPM / 60` beats early.
- Silence that isn't silent: every part needs rests there, and pads need to stop before it.
