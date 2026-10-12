# Genre recipes for backing tracks

Each recipe lists a typical tempo, the instruments, the bass and comping figures, and a drum sketch. The drum
lines here are deliberately simple and use the chord-grid style from valda-drums
(`o2 c` kick, `d` snare, `f+` closed hat, `o3 d+` ride, `o3 c+` crash). For full song-form drum
parts with fills, use the valda-drums skill.

All snippets show **one bar** in 4/4 unless stated otherwise. Repeat or transpose them per chord.

## Blues shuffle (70–130 BPM, 12-bar)

Instruments: `electric-bass` or `acoustic-bass`, `piano` or `midi-electric-guitar-clean`, drums. Swing is written as
triplets (`6` + `12` = long + short).

```alda
(tempo! 96)
electric-bass:
  # A7 bar, root–3rd–5th–6th walking shuffle
  o2 a6 a12 > c+6 c+12 e6 e12 f+6 f+12 <
midi-electric-guitar-clean:
  # boogie "Chuck Berry" shuffle on A: 5th ↔ 6th over the root
  o3 (quant 70) a6/>e< a12/>e< a6/>f+< a12/>f+< a6/>e< a12/>e< a6/>f+< a12/>f+<
midi-percussion:
  o2 c6/f+ f+12 d6/f+ f+12 c6/f+ f+12 d6/f+ f+12
```

## Rock (100–150 BPM)

Instruments: `midi-electric-guitar-overdrive` (power chords), `midi-electric-bass-pick` (driving 8ths on the root),
drums with 8th hats and backbeat on 2 & 4.

```alda
(tempo! 120)
midi-electric-guitar-overdrive:
  o2 (quant 85) e8/b/>e< e/b/>e< e/b/>e< e/b/>e< g/>d/g< g/>d/g< a/>e/a< a/>e/a<
midi-electric-bass-pick:
  o1 e8 e e e g g a a
midi-percussion:
  o2 c8/f+ f+ d/f+ f+ c/f+ c/f+ d/f+ f+
```

## Pop (90–128 BPM)

Instruments: `piano` or `midi-electric-piano-1` (quarter or 8th-note chords, or broken arpeggios),
`electric-bass` (root + passing tones, often syncopated), `midi-synth-pad-warm` (whole-note chords), drums.

```alda
(tempo! 104)
piano:
  # broken-chord (arpeggiated) C major bar
  o4 (quant 95) c8 g > c e < g > c e < g
electric-bass:
  o2 c4. c8 r8 g8 a8 b8
midi-synth-pad-warm:
  o4 (quant 100) c1/e/g
midi-percussion:
  o2 c4/f+ d/f+ c8/f+ c/f+ d4/f+
```

## Funk (95–115 BPM, 16ths)

Instruments: `midi-electric-guitar-clean` (16th scratching chords on a dominant 9 or minor 7, short `quant`),
`midi-bass-slap` or `electric-bass` (syncopated, octave pops), `midi-electric-piano-1` stabs.

```alda
(tempo! 104)
midi-electric-guitar-clean:
  o4 (quant 40) e16/g/b-/>d< r e/g/b-/>d< e/g/b-/>d< r e/g/b-/>d< r r
  e/g/b-/>d< r e/g/b-/>d< r e/g/b-/>d< e/g/b-/>d< r e/g/b-/>d<
midi-bass-slap:
  o2 (quant 60) e8 r16 >e< r8 e16 e g8 a16 b- b r >e< d
midi-percussion:
  o2 c16/f+ f+ f+ c/f+ d/f+ f+ f+ c/f+ f+ f+ c/f+ f+ d/f+ f+ c/f+ f+
```

## Jazz swing (120–220 BPM)

Instruments: `acoustic-bass` (walking quarters: chord tones on beats 1 and 3, approach notes by half step on 4),
`piano` (shell voicings, "Charleston" rhythm: dotted quarter + 8th), drums (ride: 1, 2-and-a-3, 4-and-a, hat on 2 & 4).

```alda
(tempo! 160)
acoustic-bass:
  # Dm7 | G7  (walking)
  o2 d4 f a a- | g b > d < c+
piano:
  o4 (quant 80) f4./>c< f8/b- r2 | f4./b f8/b r2
midi-percussion:
  o3 d+4 d+6/<g+> d+12 d+4 d+6/<g+> d+12 | d+4 d+6/<g+> d+12 d+4 d+6/<g+> d+12
```

## Bossa nova (120–140 BPM)

Instruments: `guitar` (nylon) with bass on 1 and the "and of 2", syncopated chord stabs; `acoustic-bass` root–fifth;
side stick plus 8th shaker/hat.

```alda
(tempo! 132)
guitar:
  # Cmaj7, partido-alto style comp
  o3 (quant 60) e8/g/b r e/g/b r r e/g/b r e/g/b
acoustic-bass:
  o1 c4. g8 g4. c8
midi-percussion:
  o2 c4/c+/f+ f+8 c+/f+ c/f+ c+/f+ f+ c+/f+
```

## Reggae one-drop (65–85 BPM)

Guitar/keys "skank" on the offbeats (very short), bass on melodic phrases leaving beat 1 empty, kick + snare
(cross-stick) together on beat 3 only.

```alda
(tempo! 76)
midi-electric-guitar-clean:
  o4 (quant 30) r8 c8/e/g r8 c/e/g r8 c/e/g r8 c/e/g
electric-bass:
  o2 r4 c8 c e g a g
midi-percussion:
  o2 f+8 f+ f+ f+ c/c+/f+ f+ f+ f+
```

## Country / train beat (100–140 BPM)

Bass alternates root–fifth ("boom-chick"), guitar strums on the offbeat.

```alda
(tempo! 120)
electric-bass:
  o2 g4 r d r
midi-acoustic-guitar-steel:
  o3 r4 g/b/>d/g< r4 g/b/>d/g<
midi-percussion:
  o2 c8/d d d c/d d d d d
```

## Metal (90–200 BPM)

Distorted guitar palm-muted chugs on the low string (`midi-electric-guitar-distorted` or `-palm-muted`, `o2 e`),
power chords on the accents, bass doubling the guitar root, and double-kick drums (see valda-drums).

```alda
(tempo! 160)
midi-electric-guitar-palm-muted:
  # gallop on E: 8th + two 16ths
  o2 (quant 60) e8 e16 e e8 e16 e e8 e16 e f8/>c< e16 e
midi-electric-bass-pick:
  o1 e8 e16 e e8 e16 e e8 e16 e f8 e16 e
midi-percussion:
  o2 c8/>c+< c16 c d8/c c16 c c8/f+ c16 c d8/c c16 c
```

## Ballad (60–80 BPM)

`piano` arpeggios in 8ths, `midi-string-ensemble-1` sustained (`(quant 100)`), `electric-bass` whole/half notes,
light drums (cross-stick, or brushes approximated by low `(vol)`).

```alda
(tempo! 70)
piano:
  o3 (quant 99) c8 g > c d e < g > c d <
midi-string-ensemble-1:
  o4 (quant 100) (vol 50) e1/g
electric-bass:
  o2 c2. g4
```

## Mix balancing

Set `(track-vol N)` per part at the top: drums 85–95, bass 85, comping 65–75, pad 50–60. Pan comping parts
apart (`(pan 35)` / `(pan 65)`). Keep bass and kick centered. If the drums use two percussion parts (kit + crash layer, see valda-drums), give both the same `(track-vol)`.
