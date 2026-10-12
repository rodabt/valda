# GM drum map for `midi-percussion:`

On the percussion part each pitch is a drum. Alda `o4 c` = MIDI 60, so `o2 c` = 36. All parts declared as
`midi-percussion` (or `percussion`) share MIDI channel 10.

## Kit pieces (rock / pop / metal)

| Piece | Alda | GM | Tab row |
|---|---|---|---|
| Kick (Bass Drum 1) | `o2 c` | 36 | BD |
| Kick 2 (Acoustic Bass Drum) | `o1 b` | 35 | BD (second kick for double-bass if you want two samples) |
| Snare (acoustic) | `o2 d` | 38 | SN |
| Snare (electric) | `o2 e` | 40 | SN (tighter pop/metal snare) |
| Side stick / cross-stick | `o2 c+` | 37 | SS |
| Hand clap | `o2 d+` | 39 | CL |
| Closed hi-hat | `o2 f+` | 42 | HH |
| Pedal hi-hat (foot) | `o2 g+` | 44 | HF |
| Open hi-hat | `o2 a+` | 46 | HO |
| Crash 1 | `o3 c+` | 49 | CR |
| Crash 2 | `o3 a` | 57 | CR |
| Ride | `o3 d+` | 51 | RD |
| Ride bell | `o3 f` | 53 | RB |
| Ride 2 | `o3 b` | 59 | RD |
| China | `o3 e` | 52 | CH |
| Splash | `o3 g` | 55 | SP |
| High tom | `o3 d` | 50 | T1 |
| Hi-mid tom | `o3 c` | 48 | T2 |
| Low-mid tom | `o2 b` | 47 | T3 |
| Low tom | `o2 a` | 45 | T4 |
| High floor tom | `o2 g` | 43 | FT |
| Low floor tom | `o2 f` | 41 | FT2 |
| Sticks (count-in) | `o1 g` | 31 | |
| Metronome click / bell | `o1 a` / `o1 a+` | 33 / 34 | |
| Tambourine | `o3 f+` | 54 | |
| Cowbell | `o3 g+` | 56 | |
| Shaker | `o5 a+` | 82 | |
| High / low woodblock | `o5 e` / `o5 f` | 76 / 77 | |

Toms from high to low: `o3 d`, `o3 c`, `o2 b`, `o2 a`, `o2 g`, `o2 f`. For a 4-piece kit use `o3 d` `o3 c` `o2 a` `o2 f`.
A descending run written from `o3` therefore needs `<` between `c` and `b`.

## Other percussion

| Alda | GM | Name | Alda | GM | Name |
|---|---|---|---|---|---|
| `o3 a+` | 58 | Vibraslap | `o4 g` | 67 | High agogo |
| `o4 c` | 60 | Hi bongo | `o4 g+` | 68 | Low agogo |
| `o4 c+` | 61 | Low bongo | `o4 a` | 69 | Cabasa |
| `o4 d` | 62 | Mute hi conga | `o4 a+` | 70 | Maracas |
| `o4 d+` | 63 | Open hi conga | `o5 d+` | 75 | Claves |
| `o4 e` | 64 | Low conga | `o5 g+` | 80 | Mute triangle |
| `o4 f` / `o4 f+` | 65 / 66 | High / low timbale | `o5 a` | 81 | Open triangle |

## Pitfalls

- A cymbal sample rings for its natural length on most SoundFonts no matter how short the note is. You can't
  "choke" a crash. For a staccato stop, end on a kick+snare hit, or kick+crash followed by silence.
- Hi-hat open → closed: GM kits usually cut the open hat when a closed or pedal hat (`f+`/`g+`) plays. An
  open hat on "&" followed by a pedal hat on the next beat gives the classic "tss-chick".
- Velocity matters more on drums than anywhere else: ghost snare ≈ `(vol 25)`, normal ≈ `(vol 85)`,
  accent ≈ `(vol 100)`, hats ≈ `(vol 60–75)`, with accents on the beat.
