# Cinematic genres: defaults and signature textures

Each genre lists defaults for everything the user didn't specify, then a short validated texture to adapt (not to
paste unchanged). "Evoke" names composers whose **style** fits. Never imitate their actual themes.
Harmony moves are spelled in `harmony.md`. Instrument ranges and the channel budget are in `orchestration.md`.

| Genre | BPM | Key / mode | Core sound | Default arc |
|---|---|---|---|---|
| Epic / action | 120–150 | D, C, E minor (aeolian) | string ostinato, low brass, taiko, choir | build → climax → tail |
| Heroic adventure | 100–130 | C, B♭, E♭ major (+ ♭VII, ♭VI) | trumpet/horn fanfare, march snare, driving strings | statement → development → triumphant restatement |
| Fantasy | 70–100 | D, F, A lydian/major, modal | harp/celesta arps, flute, strings, choir oohs | wonder → swell → glow |
| Drama / emotional | 56–76 | C, F, D♭ major with minor iv, or minor | piano ostinato, strings, solo cello/violin | intimate → swell → resolve or open end |
| Horror | 40–70 or "no pulse" | none / minor, chromatic | drones, clusters, tremolo, music box, stingers | slow burn → silence → stinger |
| Thriller / suspense | 100–130 | minor over a pedal | 16th pulse, brass mM7 stabs, timpani heartbeat | tension waves, rising pitch, cut-off |
| Sci-fi / space | 60–90 | major via chromatic mediants | synth pads, arps, choir oohs, strings | slow reveal → awe swell |
| Romance | 66–84, often 3/4 | F, E♭, A♭ major | solo violin/oboe, harp, lush strings | tender → bloom → soft close |
| Mystery / noir | 66–84 | C, F, G minor (line cliché, mM7) | muted trumpet/clarinet, upright bass, piano | smoky, static, unresolved |
| Whimsical / comedy | 110–150 (2/4, 6/8) | C, F, G major + chromatic neighbors | pizzicato, bassoon, clarinet, glockenspiel | playful phrases, a sting ending |
| War / elegy | 50–66 | D, G, B♭ minor | solo horn/trumpet, string chorale, distant snare | lament → swell → empty ending |

Evoke: epic: Zimmer, Balfe, Two Steps from Hell trailer style. Heroic: Williams, Silvestri, Giacchino. Fantasy: Shore,
Powell, Horner, Williams' Lydian writing. Drama: Thomas Newman, Desplat, Richter, Portman. Horror: Herrmann, Goldsmith,
Young, Penderecki/Ligeti-style clusters. Thriller: Herrmann, Newton Howard. Sci-fi: Zimmer (pedal + organ), Williams
mediants, Vangelis pads. Romance: Barry, Yared, Morricone. Noir: Goldsmith, Herrmann, Bernstein. Whimsical: Elfman,
Mancini, Desplat. Elegy: Barber-style string chorale, Williams' war scores.

---

## Epic / action

Minor key, i–VI–III–VII loop. A 16th-note string ostinato built from chord tones, low brass on long roots, horns
carrying a broad theme, taiko on a syncopated pattern. Leave out fussy woodwinds. Build by adding layers every 4–8
bars, raise the theme an octave and add choir + trumpets at the climax, then cut to a single low hit and a tail.

```alda
(tempo! 130)
midi-string-ensemble-1 "ostinato":
  (quant 60) (vol 80) (pan 35)
  o3 [d16 d a d >d< d a d]*2 | [d16 d b- d >d< d b- d]*2 | [c16 c a c >c< c a c]*2 | [c16 c g c >c< c g c]*2
midi-french-horn:
  (vol 90) (pan 38) (quant 95)
  o3 a2. g8 f8 | f2 d2 | f2. e8 d8 | e1
midi-trombone:
  (vol 85) (pan 68) (quant 100)
  o2 d1 | o1 b-1 | o2 f1 | o2 c1
midi-taiko-drum:
  (vol 100)
  [o2 d4 r8 d8 d4 r4]*4
```

## Heroic adventure

Major key with borrowed ♭VII/♭VI. A trumpet fanfare that opens with a leap and uses dotted or triplet pickups,
brass chords, low strings in driving 8ths, march snare. Restate the theme in the full orchestra at the end with a
I–♭VI–♭VII–I cadence.

```alda
(tempo! 116)
midi-trumpet:
  (vol 95) (pan 58)
  o4 g4. g8 >c4 e4 | d2. c8 < b-8 | a4. a8 >c4 f4< | g1
midi-brass-section:
  (vol 78) (pan 45)
  o3 g1/>c/e< | f/b-/>d< | f/a/>c< | g/>c/e<
midi-string-ensemble-1:
  (vol 72) (quant 70) (pan 65)
  o2 c8*8 | o1 b-8*8 | o2 f8*8 | o2 c8*8
midi-percussion:
  (vol 70)
  [o2 d8 d16 d d8 d d4 c]*4
```

## Fantasy

Lydian or modal major, I–II or planing triads. Harp or celesta arpeggios, a flute or solo violin melody that leans
on the ♯4, warm string pad, choir oohs at the swell. Moderate tempo, often 3/4 or 6/8 for a lilting feel.

```alda
(tempo! 84)
midi-orchestral-harp:
  (vol 65) (pan 25)
  [o3 d8 a > d f+ a f+ d < a | o3 e8 b > e g+ b g+ e < b]*2
midi-flute:
  (vol 75) (pan 50)
  o5 a2. g+4 | b1 | a4 f+4 d4 e4 | e1
midi-string-ensemble-1:
  (vol 50) (quant 100) (pan 60)
  o3 d1/a/>f+< | e/b/>g+< | d/a/>f+< | e/b/>g+<
```

## Drama / emotional

Slow harmonic rhythm (one chord per bar or two), a piano broken-chord ostinato, a sustained string bed, and a cello
or violin melody with suspensions. Borrow minor iv for the bittersweet turn. Swell to the climax by adding
violins an octave up, then pull back to piano alone.

```alda
(tempo! 66)
piano:
  (vol 55) (pan 45)
  o3 c8 g > c e g e c < g | o2 a8 o3 e a o4 c e c o3 a e | o2 f8 o3 c f a o4 c o3 a f c | o2 f8 o3 c f a- o4 c o3 a- f c
midi-cello:
  (vol 72) (pan 65) (quant 100)
  o3 g2 e4 g4 | a2. g4 | a2 >c4< a4 | a-1
midi-string-ensemble-2:
  (vol 42) (quant 100) (pan 35)
  o4 e1/g | e/a | f/a | f/a-
```

## Horror

Avoid a clear key and pulse. Use a low drone or semitone cluster in tremolo strings, a slow two-note semitone
ostinato in the contrabass that gets faster, and a fragile celesta/music-box tune with one "wrong" note. Build tension,
then **silence** (1–2 beats of rest in every part), then a loud stinger: a cluster in all registers + low piano + crash.

```alda
(tempo! 60)
midi-tremolo-strings:
  (vol 32) (quant 100) (pan 40)
  o2 c1~1~1~1/c+
midi-contrabass:
  (vol 55) (pan 72) (quant 90)
  o1 e4 f4 r2 | o1 e4 f4 r2 | o1 e8 f8 e8 f8 r2 | o1 e8 f e f e f e f
midi-celesta:
  (vol 40) (pan 25)
  o5 e4 g4 b4 >c4< | o5 b2 r2 | o5 e4 g4 b-4 a4 | r1
```

## Thriller / suspense

A relentless 16th-note pulse on one low note (spiccato strings, `quant 40`), moving up by a **semitone** every few
bars. Brass stabs on minor-major-7th chords, a timpani "heartbeat". End phrases on a cut-off, not a cadence.

```alda
(tempo! 112)
midi-string-ensemble-1 "pulse":
  (quant 40) (vol 70) (pan 40)
  o2 a16*16 | o2 a16*16 | o2 b-16*16 | o2 b-16*16
midi-french-horn:
  (vol 85) (quant 80) (pan 38)
  r1 | o3 a2/>c/e/g+< r2 | r1 | o3 b-2/>d-/f/a< r2
midi-timpani:
  (vol 80)
  o2 a4 a8 r8 r2 | o2 a4 a8 r8 r2 | o2 b-4 b-8 r8 r2 | o2 b-4 b-8 r8 r2
```

## Sci-fi / space

Wide, slow major chords linked by chromatic mediants (C → A♭ → E → C), each sharing one common tone that a choir
or high voice holds. Synth pad, a quiet saw-wave arpeggio for motion, and an organ or choir for awe at the peak.

```alda
(tempo! 72)
midi-saw-wave:
  (vol 38) (quant 70) (pan 30)
  o4 c8 g > c < g c g > c < g | o3 a-8 > e- a- e- < a- > e- a- e- | o3 b8 > e g+ e < b > e g+ e | o4 c8 g > c < g c g > c < g
midi-synth-pad-warm:
  (vol 50) (quant 100) (pan 70)
  o3 c1/g/>e< | c/a-/>e-< | b/>e/g+< | c/g/>e<
midi-voice-oohs:
  (vol 48) (quant 100)
  o4 g1 | a- | g+ | g
```

## Romance

Lyrical solo (violin or oboe) above harp arpeggios and a soft string pad, often in 3/4. Use long notes on the 9th or
the 4th resolving down. Bloom by doubling the melody in octaves (violins + cellos) for the final phrase.

```alda
# 3/4: each bar is a dotted half
(tempo! 80)
midi-orchestral-harp:
  (vol 60) (pan 25)
  o3 f8 > c f a f c | o3 d8 a > d f d < a | o3 b-8 > f b- > d < b- f | o3 c8 g > c e c < g
midi-violin:
  (vol 72) (pan 35) (quant 100)
  o5 c2 a4 | a2. | b-4 a4 g4 | g2 e4
midi-string-ensemble-2:
  (vol 42) (quant 100) (pan 60)
  o4 c2./f/a | d/f/a | d/f/b- | c/e/g
```

## Mystery / noir

Minor, smoky, slow. A line cliché in the piano (one voice falling c → b → b♭ → a), an upright bass in half notes, and a muted
trumpet or clarinet melody with blue notes. Leave space. End on an unresolved minor 6 or mM7 chord.

```alda
(tempo! 72)
piano:
  (vol 50) (pan 40)
  o3 g1/>c/e-< | g/b/>e-< | g/b-/>e-< | g/a/>e-<
midi-acoustic-bass:
  (vol 75) (pan 60)
  [o2 c2 g2]*4
midi-muted-trumpet:
  (vol 70) (pan 55)
  o4 g2 e-4 f4 | g2. r4 | a-4 g4 f4 e-4 | d2 r2
```

## Whimsical / comedy

Bouncy oom-pah in pizzicato, a staccato bassoon or clarinet tune with chromatic lower neighbors, glockenspiel or
triangle accents, and a "button" ending (one short tutti chord, or a tonic hit after a beat of silence).

```alda
(tempo! 132)
midi-pizzicato-strings:
  (vol 70) (pan 60)
  o2 c4 o3 e/g o2 g o3 e/g | o2 g4 o3 d/f o2 d o3 d/f | o2 c4 o3 e/g o2 g o3 e/g | o2 c4 r4 r2
midi-bassoon:
  (vol 78) (quant 50) (pan 40)
  o3 c8 d e f+ g4 g4 | b8 a g+ a g4 f4 | e8 d c+ d e4 g4 | c4 r4 r2
midi-glockenspiel:
  (vol 50) (pan 30)
  r1 | r1 | r1 | o6 c4 r4 r2
```

## War / elegy

Slow string chorale over a descending (lament) bass, a solo horn or trumpet melody, a distant snare roll. Swell once,
then thin out to a single unresolved note or an open fifth.

```alda
(tempo! 56)
midi-string-ensemble-1:
  (vol 55) (quant 100) (pan 40)
  o3 f2/a/>d< e/a/>c+< | f/a/>c< g/b/>d< | g/b-/>d< e/a/>c+< | e1/a/>c+<
midi-contrabass:
  (vol 60) (quant 100) (pan 72)
  o2 d2 c+ | c o1 b | b- a | a1
midi-french-horn:
  (vol 70) (pan 38) (quant 100)
  o4 d2 e2 | f2 d2 | d2 c+2 | c+1
midi-percussion:
  r1*3 | (vol 30) o2 d32*32
```
