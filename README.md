# valda

A reimplementation of [Alda](https://alda.io), the text-based music
composition language, in [V](https://vlang.io). It's a single, self-contained
binary with a built-in synthesizer: no JVM, no separate player process.

```
$ valda play -c 'piano: (tempo 132) o4 c8 d e f g4 a8 b > c2'
$ valda export -f examples/bach_cello_suite_no_1.alda -o bach.mid
$ valda export -f examples/debussy_quartet.alda -M 1 -o quartet.mid   # one track per part
$ valda export -f examples/bach_cello_suite_no_1.alda -O wav -o bach.wav
$ valda repl
```

**Status:** prototype. The language core reproduces Alda 2.4.7's behavior
exactly (see [Verification](#verification)). Everything from the Alda client
is ported except the WebAssembly target and features tied to Alda's
background-process architecture.

## Building

Requires V (tested with 0.5.1). No other dependencies: the synthesizer and
audio I/O are vendored single-header C libraries.

```
v -o valda .                     # development build (tcc)
v -prod -cc gcc -o valda .       # optimized build (~1.5 MB)
v test .                         # run the test suite
```

On Linux, audio goes through PulseAudio/PipeWire, ALSA or JACK, loaded at
runtime (no `-dev` packages needed). miniaudio also supports Core Audio on
macOS and WASAPI/DirectSound on Windows, but so far valda has only been built
and tested on Linux (WSL2).

### SoundFont

Playback needs a General MIDI SoundFont (`.sf2`). valda looks for one in this
order:

1. `--soundfont /path/to/file.sf2` (or `-S`)
2. the `VALDA_SOUNDFONT` environment variable
3. `default.sf2` (or any `.sf2`) in the config directory (`~/.config/valda/` on Linux)
4. well-known system locations, e.g. `/usr/share/sounds/sf2/` (Debian's
   `fluid-soundfont-gm` / `timgm6mb-soundfont` packages)

[GeneralUser GS](https://schristiancollins.com/generaluser.php) is a good,
free, ~30 MB choice. Run `valda doctor` to check your setup.

## Commands

| Command | Description |
|---|---|
| `play` | Evaluate and play Alda code (`-f`, `-c` or stdin; `--from`/`--to` markers or times). `-p PORT` plays in a running REPL server instead. |
| `parse` | Show the AST (`-o ast`, `ast-human`), events (`-o events`) or score data (`-o data`) as JSON |
| `export` | Export to MIDI (`-O midi`, default) or WAV (`-O wav`, rendered offline faster than real time). MIDI is format 0 (one track, as in Alda) unless `-M 1` asks for format 1: a tempo track plus one track per part, named after the part's alias or instrument. |
| `import` | Import MusicXML (`-i musicxml`) into Alda code |
| `format` | Format Alda code (experimental; drops comments, as in Alda) |
| `repl` | Interactive REPL plus nREPL server (`--server`, `--client`, `--port`, `--message`) |
| `stop` | Stop playback in a running REPL server |
| `instruments`, `version`, `doctor` | |

The REPL server speaks the same nREPL protocol (bencode over TCP) as Alda's,
with the same ops (`eval-and-play`, `load`, `replay`, `score-data`, `export`,
etc.) and the same `.alda-nrepl-port` file. Alda editor integrations should
therefore work with it.

## Architecture

```
            ┌──────────┐   ┌──────────────┐   ┌───────────┐
 .alda ───▶ │ parser   │──▶│ model        │──▶│ playback  │──▶ engine (C): TinySoundFont + miniaudio ──▶ 🔊
            │ scanner, │   │ score, parts,│   │ timed MIDI│──▶ smf: Standard MIDI File
 MusicXML ─▶│ AST      │   │ alda-lisp    │   │ messages  │──▶ offline render ──▶ WAV
  musicxml  └──────────┘   └──────────────┘   └───────────┘
                                   ▲
                    repl: nREPL server/client (bencode over TCP)
```

| Module | Lines | Port of |
|---|---:|---|
| `parser/` | 2.9k | `client/parser` (scanner, parser, AST → updates, formatter, AST generation) |
| `model/` | 3.7k | `client/model` (score semantics, attributes, alda-lisp, MIDI channel assignment, JSON) |
| `musicxml/` | 1.8k | `client/interop/musicxml/importer` |
| `repl/` | 1.1k | `client/repl` (nREPL server and client, bencode) |
| `playback/` | 0.4k | `client/transmitter` and the scheduling logic of the Kotlin `player` |
| `smf/` | 0.2k | the player's MIDI export (format 0, 128 PPQ, tempo map), plus format 1 (one track per part) |
| `engine/` | 0.4k | replaces the JVM's `javax.sound.midi` Sequencer and Gervill synthesizer |

Where Alda runs a separate JVM player and talks to it over OSC, valda does
everything in one process:

- **The engine** (`engine/valda_engine.c`) owns the audio thread. Events are
  queued on a sample-accurate timeline (in frames), and the audio callback
  applies each one at the exact frame it's due, splitting rendering at event
  boundaries. Only the audio thread touches the synthesizer; other threads talk
  to it through a mutex-protected queue. Measured onset error in rendered audio
  is constant at ~0.3 ms (the sample's attack), with no drift.
- **The player** (`playback/live.v`) keeps Alda's per-track semantics. Each
  part has a position (the end of its last scheduled note), and new input
  starts at the later of that position and "now". That way REPL input lines
  up after what's already playing.
- Program changes, expression (CC 11, "track volume") and panning (CC 10) are
  sent only when they change on a channel, exactly as Alda's transmitter does.

## Verification

The port was checked against the reference implementation (Alda's Go client,
built from the alda repository) by differential testing:

- **All 29 example scores:** `parse -o events`, `-o data`, `-o ast` and
  `-o ast-human` are **byte-identical** (116/116). This covers note timing,
  voices, cram, repeats, variables, markers, global attributes, key
  signatures and MIDI channel allocation.
- **A 179-input edge-case corpus** (every `given:` snippet from Alda's parser
  tests, plus ~85 hand-written cases including error cases): identical output
  and exit status for both `events` and `data`. Error messages are identical
  too, including line:column positions.
- **`format`**: byte-identical for all 29 examples.
- **MusicXML import**: identical for all 27 example files, except for key
  signature letter order (see below).
- **MIDI export**: every example's `.mid` passes a strict independent parser,
  and every note matches the score's events (pitch, channel, velocity) within
  tick quantization.

`tests/golden_test.v` locks in a subset of this as recorded golden output (`v
test .`). `scripts/difftest.sh` re-runs the full comparison against any `alda`
binary (`ALDA=/path/to/alda scripts/difftest.sh`).

## Differences from Alda

Intentional:

- **No background processes.** `alda play` hands the score to a background
  player and returns at once. `valda play` plays in-process and returns when
  playback ends. For the fire-and-forget workflow, run a REPL server and use
  `valda play -p PORT` or `valda stop`. As a result, `ps`, `shutdown` and the
  player-management parts of `doctor` don't exist.
- **No telemetry or self-update** (`alda telemetry`, `alda update`).
- **Deterministic key signature output.** In MusicXML import, letters come in
  circle-of-fifths order (`f+ c+ g+`). Alda's order is random, because it
  iterates a Go map.
- **Clean errors instead of crashes.** For example, `piano: {}` panics in
  Alda, while valda reports `empty cram expression`. Error messages don't
  include Go struct dumps (`%#v`).
- **`stop` in the REPL** also forgets the track positions, so the next input
  starts immediately.
- **WAV export** (`-O wav`) is new.
- **Sound:** TinySoundFont plus your SoundFont, instead of the JVM's Gervill
  and its built-in soundbank. Instruments and the volume curve will sound
  somewhat different.

Not ported: the WebAssembly target (`client/wasm`), and `-v` log verbosity.

## Next steps

- Use [midvi](https://github.com/Krotki/midvi) as an optional backend, to
  drive external MIDI devices and DAWs alongside (or instead of) the built-in
  synth.
- Bundle a small default SoundFont, or download one on first use.
- Port the remaining Go unit tests for the model (they build score updates
  directly in Go, so they need translating rather than recording).

## License

Copyright © 2026 Rodrigo Abt.
Based on [Alda](https://github.com/alda-lang/alda), copyright © 2012-2026 Dave
Yarwood et al.

valda is distributed under the Eclipse Public License 2.0 (see `LICENSE`),
like Alda, from which most of its code is translated. It is an independent
project, not affiliated with or endorsed by the Alda project.

Some parts have their own licenses; `NOTICE` lists them all:

- The vendored C libraries and the V runtime compiled into the binary are MIT
  or public domain (see `thirdparty/`).
- `examples/nicechord-alda-demo.alda` is CC BY-SA 4.0.

Binary distributions of valda must include `LICENSE`, `NOTICE` and the license
files in `thirdparty/`, and must say where to get the source code. `valda
version` prints that location (`source_url` in `main.v`).
