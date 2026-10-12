# Groove library: rock, pop, metal

Every groove is one 4/4 bar, written as a **limb-voice variable**: `V1` hands on cymbals (or a timekeeping tom),
`V2` snare/toms, `V3` kick. The tab comment above it is the source of truth. Edit the tab, then make the code match.

Tab symbols: `x` normal, `X` accent, `g` ghost, `.` rest. Rows: HH closed hat, HO open hat, RD ride, CR crash,
CH china, SN snare, SS cross-stick, CL clap, FT floor tom, T2 hi-mid tom, BD kick (see `gm-drum-map.md`).

Volumes: hats/cymbals 70 (accent 90, soft 40), snare and toms 90 (accent 100, ghost 28), kick 92 (accent 100),
a floor tom used for timekeeping 65 (it booms and masks the snare at 90).
**Every voice sets its own `(vol N)` and `oN` on its first note.** Voices leak attributes after `V0:`
(see the valda-music skill's `alda-syntax.md`), so explicit values keep each groove independent of what came before.

Use a groove as-is with `rock8*4`. For a variation bar, copy the groove under a new name (`rock8b`) and change one
or two hits, most often the kick on beat 4 or an open hat on the last "&".
Tempo ranges are where each style usually sits. Outside that range it still plays, but the style may not feel right.

## Rock
### `rock8`: Basic rock, 8th hats (90–150 BPM)

The default rock beat. Variations: kick on the "&" of 4 (`x... xx.x`), or ride instead of hats for choruses.

```alda
#     1 & 2 & 3 & 4 &
# HH  X x X x X x X x
# SN  . . x . . . x .
# BD  x . . . x x . .
rock8 = [
  V1: (vol 90) o2 f+8 (vol 70) f+ (vol 90) f+ (vol 70) f+ (vol 90) f+ (vol 70) f+ (vol 90) f+ (vol 70) f+
  V2: r8 r (vol 90) o2 d r r r d r
  V3: (vol 92) o2 c8 r r r c c r r
  V0:
]
midi-percussion: rock8*2
```
### `rock16`: Rock, 16th hats with ghost notes (75–110 BPM)

For mid-tempo rock and pop-rock. Ghost notes (`g`) are `(vol 28)`. Drop them for a straighter feel.

```alda
#     1 e & a 2 e & a 3 e & a 4 e & a
# HH  X x x x X x x x X x x x X x x x
# SN  . . . . x . . g . . g . x . . .
# BD  x . . . . . . x x . x . . . . .
rock16 = [
  V1: (vol 90) o2 f+16 (vol 70) f+ f+ f+ (vol 90) f+ (vol 70) f+ f+ f+ (vol 90) f+ (vol 70) f+ f+ f+ (vol 90) f+ (vol 70) f+ f+ f+
  V2: r16 r r r (vol 90) o2 d r r (vol 28) d r r d r (vol 90) d r r r
  V3: (vol 92) o2 c16 r r r r r r c c r c r r r r r
  V0:
]
midi-percussion: rock16*2
```
### `halfTime`: Half-time feel (120–170 BPM)

The snare only on 3 makes the song feel half as fast. Use it for bridges, big choruses, and metal "drops".

```alda
#     1 & 2 & 3 & 4 &
# HH  x x x x x x x x
# SN  . . . . x . . .
# BD  x . . . . . x .
halfTime = [
  V1: (vol 70) o2 f+8 f+ f+ f+ f+ f+ f+ f+
  V2: r8 r r r (vol 90) o2 d r r r
  V3: (vol 92) o2 c8 r r r r r c r
  V0:
]
midi-percussion: halfTime*2
```
### `shuffle`: Shuffle (triplet feel) (80–140 BPM)

Blues-rock and boogie. The grid is 8th-note triplets (`12`). Swap hats for ride in the solo.

```alda
#     1 & a 2 & a 3 & a 4 & a
# HH  x . x x . x x . x x . x
# SN  . . . x . . . . . x . .
# BD  x . . . . x x . . . . .
shuffle = [
  V1: (vol 70) o2 f+12 r f+ f+ r f+ f+ r f+ f+ r f+
  V2: r12 r r (vol 90) o2 d r r r r r d r r
  V3: (vol 92) o2 c12 r r r r c c r r r r r
  V0:
]
midi-percussion: shuffle*2
```
### `tomGroove`: Floor-tom groove (tribal) (100–140 BPM)

For intros and verses that need tension without hats. The floor tom takes over the timekeeping.

```alda
#     1 e & a 2 e & a 3 e & a 4 e & a
# FT  x . x . x . x . x . x . x . x .
# SN  . . . . x . . . . . . . x . . .
# T2  . . . . . . . . . . x . . . . .
# BD  x . . x . . x . x . . x . . . .
tomGroove = [
  V1: (vol 65) o2 f16 r f r f r f r f r f r f r f r
  V2: r16 r r r (vol 90) o2 d r r r r r o3 c r o2 d r r r
  V3: (vol 92) o2 c16 r r c r r c r c r r c r r r r
  V0:
]
midi-percussion: tomGroove*2
```

## Pop
### `fourFloor`: Four-on-the-floor, open hat offbeats (115–130 BPM)

Dance-pop and disco-rock. Clap layered on the snare. The open hat on every "&" is the hook.

```alda
#     1 & 2 & 3 & 4 &
# HO  . x . x . x . x
# CL  . . x . . . x .
# SN  . . x . . . x .
# BD  x . x . x . x .
fourFloor = [
  V1: r8 (vol 70) o2 a+ r a+ r a+ r a+
  V2: r8 r (vol 90) o2 d+/d r r r d+/d r
  V3: (vol 92) o2 c8 r c r c r c r
  V0:
]
midi-percussion: fourFloor*2
```
### `disco`: Disco, 16th hats (110–125 BPM)

Closed hat on the beats with an open hat on each "&". The kick plays every beat.

```alda
#     1 e & a 2 e & a 3 e & a 4 e & a
# HH  x . x . x . x . x . x . x . x .
# HO  . . x . . . x . . . x . . . x .
# SN  . . . . x . . . . . . . x . . .
# BD  x . . . x . . . x . . . x . . .
disco = [
  V1: (vol 70) o2 f+16 r f+/a+ r f+ r f+/a+ r f+ r f+/a+ r f+ r f+/a+ r
  V2: r16 r r r (vol 90) o2 d r r r r r r r d r r r
  V3: (vol 92) o2 c16 r r r c r r r c r r r c r r r
  V0:
]
midi-percussion: disco*2
```
### `popSync`: Modern pop, syncopated kick (90–110 BPM)

The kick on the "&" of 2 and 3 locks with a syncopated bass line.

```alda
#     1 e & a 2 e & a 3 e & a 4 e & a
# HH  X x X x X x X x X x X x X x X x
# SN  . . . . X . . . . . . . X . . g
# BD  x . . . . . x . . . x . . . . .
popSync = [
  V1: (vol 90) o2 f+16 (vol 70) f+ (vol 90) f+ (vol 70) f+ (vol 90) f+ (vol 70) f+ (vol 90) f+ (vol 70) f+ (vol 90) f+ (vol 70) f+ (vol 90) f+ (vol 70) f+ (vol 90) f+ (vol 70) f+ (vol 90) f+ (vol 70) f+
  V2: r16 r r r (vol 100) o2 d r r r r r r r d r r (vol 28) d
  V3: (vol 92) o2 c16 r r r r r c r r r c r r r r r
  V0:
]
midi-percussion: popSync*2
```
### `balladStick`: Ballad, cross-stick (60–85 BPM)

Verses of ballads. Switch to a full snare (`SN`) and ride or crash for the chorus.

```alda
#     1 & 2 & 3 & 4 &
# HH  x x x x x x x x
# SS  . . x . . . x .
# BD  x . . x . x . .
balladStick = [
  V1: (vol 70) o2 f+8 f+ f+ f+ f+ f+ f+ f+
  V2: r8 r (vol 90) o2 c+ r r r c+ r
  V3: (vol 92) o2 c8 r r c r c r r
  V0:
]
midi-percussion: balladStick*2
```
### `punkSkank`: Pop-punk / punk "skank" (160–220 BPM)

Kick on the beat, snare on every "&". Use the ride (or a washy crash) in choruses and hats in verses.

```alda
#     1 & 2 & 3 & 4 &
# RD  x x x x x x x x
# SN  . x . x . x . x
# BD  x . x . x . x .
punkSkank = [
  V1: (vol 70) o3 d+8 d+ d+ d+ d+ d+ d+ d+
  V2: r8 (vol 90) o2 d r d r d r d
  V3: (vol 92) o2 c8 r c r c r c r
  V0:
]
midi-percussion: punkSkank*2
```

## Metal
### `doubleKick`: Double-kick 16ths (100–180 BPM)

Continuous 16th kicks, a crash or china on the quarters, and the snare on 2 and 4. Above ~190 BPM use 8th-triplet or 8th kicks instead.

```alda
#     1 e & a 2 e & a 3 e & a 4 e & a
# CR  x . . . x . . . x . . . x . . .
# SN  . . . . x . . . . . . . x . . .
# BD  x x x x x x x x x x x x x x x x
doubleKick = [
  V1: (vol 70) o3 c+16 r r r c+ r r r c+ r r r c+ r r r
  V2: r16 r r r (vol 90) o2 d r r r r r r r d r r r
  V3: (vol 92) o2 c16 c c c c c c c c c c c c c c c
  V0:
]
midi-percussion: doubleKick*2
```
### `gallop`: Gallop (140–190 BPM)

An 8th and two 16ths on the kick, doubling the guitar gallop (NWOBHM, power metal).

```alda
#     1 e & a 2 e & a 3 e & a 4 e & a
# RD  x . x . x . x . x . x . x . x .
# SN  . . . . x . . . . . . . x . . .
# BD  x . x x x . x x x . x x x . x x
gallop = [
  V1: (vol 70) o3 d+16 r d+ r d+ r d+ r d+ r d+ r d+ r d+ r
  V2: r16 r r r (vol 90) o2 d r r r r r r r d r r r
  V3: (vol 92) o2 c16 r c c c r c c c r c c c r c c
  V0:
]
midi-percussion: gallop*2
```
### `dBeat`: D-beat (150–200 BPM)

Crust, hardcore and thrash verses. A washy crash or ride on every 8th.

```alda
#     1 & 2 & 3 & 4 &
# CR  x x x x x x x x
# SN  . . x . . . x .
# BD  x . . x x . . .
dBeat = [
  V1: (vol 70) o3 c+8 c+ c+ c+ c+ c+ c+ c+
  V2: r8 r (vol 90) o2 d r r r d r
  V3: (vol 92) o2 c8 r r c c r r r
  V0:
]
midi-percussion: dBeat*2
```
### `thrashSkank`: Thrash skank beat (180–240 BPM)

Same skeleton as the punk skank, played tighter and faster, with hats or ride. This is the main thrash verse beat.

```alda
#     1 & 2 & 3 & 4 &
# HH  X x X x X x X x
# SN  . x . x . x . x
# BD  x . x . x . x .
thrashSkank = [
  V1: (vol 90) o2 f+8 (vol 70) f+ (vol 90) f+ (vol 70) f+ (vol 90) f+ (vol 70) f+ (vol 90) f+ (vol 70) f+
  V2: r8 (vol 90) o2 d r d r d r d
  V3: (vol 92) o2 c8 r c r c r c r
  V0:
]
midi-percussion: thrashSkank*2
```
### `blastTrad`: Blast beat, traditional (180–260 BPM)

Kick + cymbal alternating with snare on 16ths. At the top tempo, write it as 8ths (`2`) with half the BPM.

```alda
#     1 e & a 2 e & a 3 e & a 4 e & a
# RD  x . x . x . x . x . x . x . x .
# SN  . x . x . x . x . x . x . x . x
# BD  x . x . x . x . x . x . x . x .
blastTrad = [
  V1: (vol 70) o3 d+16 r d+ r d+ r d+ r d+ r d+ r d+ r d+ r
  V2: r16 (vol 90) o2 d r d r d r d r d r d r d r d
  V3: (vol 92) o2 c16 r c r c r c r c r c r c r c r
  V0:
]
midi-percussion: blastTrad*2
```
### `blastHammer`: Blast beat, hammer (unison) (200–280 BPM)

Kick, snare and cymbal together on every 8th. A wall of sound for short bursts.

```alda
#     1 & 2 & 3 & 4 &
# RD  x x x x x x x x
# SN  x x x x x x x x
# BD  x x x x x x x x
blastHammer = [
  V1: (vol 70) o3 d+8 d+ d+ d+ d+ d+ d+ d+
  V2: (vol 90) o2 d8 d d d d d d d
  V3: (vol 92) o2 c8 c c c c c c c
  V0:
]
midi-percussion: blastHammer*2
```
### `breakdown`: Half-time breakdown with china (110–150 BPM)

Metalcore/deathcore. The kick doubles the guitar chug rhythm, so edit it to match the riff. The snare only lands on 3.

```alda
#     1 e & a 2 e & a 3 e & a 4 e & a
# CH  X . . . X . . . X . . . X . . .
# SN  . . . . . . . . X . . . . . . .
# BD  x x . . x . . x x . . . . x . x
breakdown = [
  V1: (vol 90) o3 e16 r r r e r r r e r r r e r r r
  V2: r16 r r r r r r r (vol 100) o2 d r r r r r r r
  V3: (vol 92) o2 c16 c r r c r r c c r r r r c r c
  V0:
]
midi-percussion: breakdown*2
```

## Combining grooves with a section crash

The bar after a fill or a section change starts with a crash on beat 1. Use a copy of the groove with the crash
added to `V1` on the first step (replacing the hat there):

```alda
rock8crash = [
  V1: (vol 95) o3 c+8 (vol 70) o2 f+ (vol 90) f+ (vol 70) f+ (vol 90) f+ (vol 70) f+ (vol 90) f+ (vol 70) f+
  V2: r8 r (vol 90) o2 d r r r d r
  V3: (vol 100) o2 c8 r r r c c r r
  V0:
]
midi-percussion: rock8crash
```
