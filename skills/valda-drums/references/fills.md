# Fills, builds, hits and endings

Fills are one-bar limb-voice variables like the grooves (see `grooves.md` for the tab symbols and the
volume conventions). A fill **replaces** the last bar of a phrase. It doesn't sit on top of the groove. The crash that
follows a fill goes on beat 1 of the next bar, using the crash layer described in `song-structure.md`.

Where fills go: the last bar of every 4- or 8-bar phrase gets either a **variation** (one changed kick or an open hat) or a
**fill**. Small fills (`fillBeat4`) work inside a section. Bigger ones (`fillToms`, `fillTriplets`) go at section
changes. The biggest fill comes before the last chorus. Not every phrase needs one: a groove that runs 8 bars
untouched and then gets a fill hits harder than one with a fill every 2 bars.

## `fillBeat4`: 1-beat snare fill (last beat)

The smallest fill: rock8 for 3 beats, then four snare 16ths. Use it at the end of 4-bar phrases inside a section.

```alda
#     1 e & a 2 e & a 3 e & a 4 e & a
# HH  x . x . x . x . x . x . . . . .
# SN  . . . . x . . . . . . . x x x X
# BD  x . . . . . . . x . x . . . . .
fillBeat4 = [
  V1: (vol 70) o2 f+16 r f+ r f+ r f+ r f+ r f+ r r r r r
  V2: r16 r r r (vol 90) o2 d r r r r r r r d d d (vol 100) d
  V3: (vol 92) o2 c16 r r r r r r r c r c r r r r r
  V0:
]
midi-percussion: fillBeat4
```

## `fillHalfBar`: 2-beat fill, snare to toms

Leads from verse to pre-chorus. The kick on beats 3 and 4 holds the time under the hands.

```alda
#     1 e & a 2 e & a 3 e & a 4 e & a
# HH  x . x . x . x . . . . . . . . .
# SN  . . . . x . . . x x x x . . . .
# T1  . . . . . . . . . . . . x x . .
# T2  . . . . . . . . . . . . . . x x
# BD  x . . . . . . . x . . . x . . .
fillHalfBar = [
  V1: (vol 70) o2 f+16 r f+ r f+ r f+ r r r r r r r r r
  V2: r16 r r r (vol 90) o2 d r r r d d d d o3 d d c c
  V3: (vol 92) o2 c16 r r r r r r r c r r r c r r r
  V0:
]
midi-percussion: fillHalfBar
```

## `fillToms`: 1-bar descending tom run (16ths)

The classic section-change fill: snare, high, mid, floor, one beat each. Follow it with a crash and kick.

```alda
#     1 e & a 2 e & a 3 e & a 4 e & a
# SN  X x x x . . . . . . . . . . . .
# T1  . . . . X x x x . . . . . . . .
# T2  . . . . . . . . X x x x . . . .
# FT  . . . . . . . . . . . . X x x x
# BD  x . . . x . . . x . . . x . . .
fillToms = [
  V1: (vol 100) o2 d16 (vol 90) d d d (vol 100) o3 d (vol 90) d d d (vol 100) c (vol 90) c c c (vol 100) o2 f (vol 90) f f f
  V2: (vol 92) o2 c16 r r r c r r r c r r r c r r r
  V0:
]
midi-percussion: fillToms
```

## `fillTriplets`: 1-bar triplet tom fill (Bonham-style)

8th-note triplets around the kit. Gives a rolling, "big" rock feel, and works in straight-8th songs too.

```alda
#     1 & a 2 & a 3 & a 4 & a
# SN  X x x . . . . . . . . .
# T1  . . . X x x . . . . . .
# T2  . . . . . . X x x . . .
# FT  . . . . . . . . . X x x
# BD  x . . x . . x . . x . .
fillTriplets = [
  V1: (vol 100) o2 d12 (vol 90) d d (vol 100) o3 d (vol 90) d d (vol 100) c (vol 90) c c (vol 100) o2 f (vol 90) f f
  V2: (vol 92) o2 c12 r r c r r c r r c r r
  V0:
]
midi-percussion: fillTriplets
```

## `fillLinear`: Linear fill (snare–tom–kick)

No two limbs hit together. The repeating groups of 3 across 16ths make a cascading, modern fill.

```alda
#     1 e & a 2 e & a 3 e & a 4 e & a
# SN  x . . x . . x . . x . . x . . X
# T1  . x . . x . . x . . x . . x . .
# BD  . . x . . x . . x . . x . . x .
fillLinear = [
  V1: (vol 90) o2 d16 o3 d r o2 d o3 d r o2 d o3 d r o2 d o3 d r o2 d o3 d r (vol 100) o2 d
  V2: r16 r (vol 92) o2 c r r c r r c r r c r r c r
  V0:
]
midi-percussion: fillLinear
```

## `fillMetal`: Metal fill: toms over double kick

The tom run with continuous 16th kicks underneath. Resolve to a china or crash on the next "1".

```alda
#     1 e & a 2 e & a 3 e & a 4 e & a
# SN  x x x x . . . . . . . . . . . .
# T1  . . . . x x x x . . . . . . . .
# T2  . . . . . . . . x x x x . . . .
# FT  . . . . . . . . . . . . x x x X
# BD  x x x x x x x x x x x x x x x x
fillMetal = [
  V1: (vol 90) o2 d16 d d d o3 d d d d c c c c o2 f f f (vol 100) f
  V2: (vol 92) o2 c16 c c c c c c c c c c c c c c c
  V0:
]
midi-percussion: fillMetal
```

## `fillStop`: Stop / hits

The band hits beat 1 and stops, then a pickup hit on the "&" of 4 leads back in. Line the hits up with the other instruments.

```alda
#     1 e & a 2 e & a 3 e & a 4 e & a
# CR  X . . . . . . . . . . . . . . .
# SN  . . . . . . . . . . . . . . X .
# BD  X . . . . . . . . . . . . . X .
fillStop = [
  V1: (vol 90) o3 c+16 r r r r r r r r r r r r r r r
  V2: r16 r r r r r r r r r r r r r (vol 100) o2 d r
  V3: (vol 100) o2 c16 r r r r r r r r r r r r r c r
  V0:
]
midi-percussion: fillStop
```

## `fillSnare8to16`: Snare build, 8ths into 16ths

One-bar build into a chorus. For a longer build, see the 4-bar crescendo below.

```alda
#     1 e & a 2 e & a 3 e & a 4 e & a
# SN  x . x . x . x . x x x x x x x X
# BD  x . . . x . . . x . . . x . . .
fillSnare8to16 = [
  V1: (vol 90) o2 d16 r d r d r d r d d d d d d d (vol 100) d
  V2: (vol 92) o2 c16 r r r c r r r c r r r c r r r
  V0:
]
midi-percussion: fillSnare8to16
```

## Single-voice fills

For fills that use one limb (or chords for unison hits), a single voice is shorter. Start with an explicit
`(vol N) oN` and a duration.

```alda
# 32nd-note snare roll on beat 4 (8 strokes). A cram {} squeezes the notes into one beat.
fillRoll = (vol 90) o2 c8/d d c/d d c/d d (vol 100) {d d d d d d d d}4
midi-percussion: fillRoll
```

```alda
# 16th-triplet ("sextuplet") tom run over beats 3–4: 12 notes in 2 beats.
fillSextuplet = (vol 90) o2 c4/d d (vol 95) {o3 d d d c c c o2 a a a f f f}2
midi-percussion: fillSextuplet
```

## 4-bar crescendo build (into a chorus or drop)

The note values get shorter and the volume rises bar by bar, with the kick on quarters underneath. This is common at the end of a
pre-chorus or before a breakdown.

```alda
buildUp = [
  V1: (vol 50) o2 d8 d d d d d d d | (vol 65) d d d d d d d d |
      (vol 80) d16 d d d d d d d d d d d d d d d |
      (vol 90) d32 d d d d d d d d d d d (vol 95) d d d d d d d d d d d d (vol 100) d d d d d d d d
  V2: (vol 80) o2 c4 c c c | c c c c | c c c c | c c c c
  V0:
]
midi-percussion: buildUp
```

## Endings

```alda
# Big ending: tom run, then a kick + crash + floor tom hit that rings for 2 bars.
endingBig = [
  V1: (vol 100) o2 r1 | o3 c+1 | r1
  V2: (vol 95) o2 d16 d d d o3 d d d d c c c c o2 f f f f | f1 | r1
  V3: (vol 100) o2 c4 c c c | c1 | r1
  V0:
]
midi-percussion: endingBig
```

```alda
# Ritardando into the final hit. (tempo! …) is global, so every part slows down with the drums.
# Write the last bar as one voice so each tempo step lands on a beat.
endingRit = (vol 90) o2 (tempo! 110) c8/f+ f+ (tempo! 100) d/f+ f+ (tempo! 88) c/f+ c/f+ (tempo! 75) d/f+ f+ | (tempo! 65) (vol 100) c1/o3 c+ | r1
midi-percussion: (tempo! 120) endingRit
```

Put the ritard in the first part (the drums). Cymbals can't be choked (see `gm-drum-map.md`), so end with the hit
and then rests.
