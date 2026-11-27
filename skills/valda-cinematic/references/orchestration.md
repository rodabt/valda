# Orchestration in valda (GM instruments)

`o4 c` = middle C (MIDI 60). Ranges are **sounding** pitch, written in Alda octaves. "Sweet spot" is where the
GM sample sounds best and the real instrument is comfortable. Stay inside it for melodies.

## The orchestra, by section

| Section | valda instrument | Range | Sweet spot | Typical role |
|---|---|---|---|---|
| Woodwinds | `midi-piccolo` | `o5 d`–`o8 c` | `o6`–`o7` | doubling violins 8va at climaxes, sparkle |
| | `midi-flute` | `o4 c`–`o7 c` | `o5`–`o6` | lyrical/fantasy melody, runs, airy doubling |
| | `midi-oboe` | `o3 b-`–`o5 a` | `o4`–`o5` | pastoral or plaintive solo, sad melody |
| | `midi-english-horn` | `o3 e`–`o5 a` | `o4` | melancholy solo, distant/lonely |
| | `midi-clarinet` | `o3 d`–`o6 b-` | `o4`–`o5` | warm melody, mysterious low register (`o3`) |
| | `midi-bassoon` | `o1 b-`–`o5 e` | `o2`–`o3` | bass line in light textures, comic staccato |
| Brass | `midi-french-horn` | `o2 b`–`o5 f` | `o3`–`o4` | **the** heroic/noble melody, warm pads, swells |
| | `midi-trumpet` | `o3 f+`–`o6 d` | `o4`–`o5` | fanfares, climactic melody, triumph |
| | `midi-muted-trumpet` | `o3 f+`–`o5 g` | `o4` | noir, distant, ironic |
| | `midi-trombone` | `o2 e`–`o5 f` (bass trombone to `o1 b-`) | `o2`–`o3` | power chords, low ostinato accents, menace |
| | `midi-tuba` | `o1 d`–`o4 f` | `o1`–`o2` | bass under the brass, dark weight |
| | `midi-brass-section` | `o2`–`o5` | `o3`–`o4` | one-channel brass chords (saves channels) |
| Percussion | `midi-timpani` | `o2 d`–`o3 c` | `o2` | roots/fifths on hits, rolls, crescendos |
| | `midi-taiko-drum` | `o2`–`o3` | `o2` | epic/hybrid pulse, impacts |
| | `midi-percussion` | GM map | | bass drum, snare, cymbals, triangle (see below) |
| | `midi-tubular-bells` | `o4 c`–`o5 f` | `o4` | doom, church, ritual tolling |
| | `midi-glockenspiel` | `o5 g`–`o8 c` | `o5`–`o6` | sparkle, magic, childlike |
| | `midi-celesta` | `o4 c`–`o8 c` | `o5`–`o6` | wonder, music box, creepy innocence |
| Keys/harp | `midi-orchestral-harp` | `o1 c`–`o7 g` | `o3`–`o6` | arpeggios, glissandi, fantasy shimmer |
| | `piano` | full | `o2`–`o6` | drama/intimate ostinatos, low "doom" notes |
| Choir | `midi-choir-aahs` | `o2 e`–`o5 a` | `o3`–`o5` | epic/sacred power, horror (low, clustered) |
| | `midi-voice-oohs` | `o3`–`o5` | `o4` | soft halo, sci-fi, grief |
| Strings | `midi-violin` | `o3 g`–`o7 e` | `o4`–`o6` | solo violin melody |
| | `midi-viola` | `o3 c`–`o6 e` | `o3`–`o4` | inner harmony, dark solo |
| | `midi-cello` | `o2 c`–`o5 a` | `o2`–`o4` | expressive solo, bass of chamber textures |
| | `midi-contrabass` | `o1 e`–`o3 g` (C extension to `o1 c`) | `o1`–`o2` | foundation, horror drones |
| | `midi-string-ensemble-1` | `o1`–`o6` | `o2`–`o5` | the main string body: pads, ostinatos, melody |
| | `midi-string-ensemble-2` | same | | slower attack: pads/second string section |
| | `midi-tremolo-strings` | same | | tension, swells, horror, shimmer |
| | `midi-pizzicato-strings` | same | | light pulse, comedy, suspense ticks |
| Synth (hybrid) | `midi-synth-pad-warm`, `-halo`, `-sweep`, `-bowed` | | `o3`–`o4` | sci-fi beds, modern hybrid glue |
| | `midi-synth-strings-1`, `midi-saw-wave` | | | pulsing arps, synth ostinatos |
| | `midi-fx-atmosphere`, `-soundtrack`, `-sci-fi`, `-echoes`, `-goblins` | | | texture beds, unease |
| | `midi-reverse-cymbal` | | `o4 c` | rising swoosh into a hit (see timing below) |
| | `midi-orchestra-hit` | | `o3`–`o4` | 80s/90s stab. Use sparingly |

## Channel budget (the hard limit)

valda has **15 melodic channels plus drums**. If more melodic parts sound at once, `valda` fails with
"No MIDI channel available". Each `instrument "alias":` part takes its own channel. All `midi-percussion` parts share channel 10.
Plan the parts before writing:

| Ensemble | Parts (≤ 15 melodic) |
|---|---|
| **Full orchestra** (12–14) | flute, oboe or clarinet, horns, trumpets, trombones (+ tuba via doubling), timpani, harp, choir, violins (ensemble-1 `"violins"`), violas+cellos (ensemble-1 `"low-strings"`), contrabass, tremolo strings, perc (ch 10) |
| **Chamber / intimate** (5–8) | piano, cello, violin, string-ensemble-2 pad, harp or celesta, horn or clarinet |
| **Hybrid epic** (10–13) | strings ostinato, low strings, horns, trombones, trumpets or brass-section, choir, taiko, timpani, synth pad, synth pulse, reverse cymbal, perc (ch 10) |
| **Horror** (6–9) | contrabass, tremolo strings, string-ensemble-2 cluster, celesta or music box, piano (low), fx pad, choir (low), perc (ch 10) |

To save channels: put **sections**, not players, on parts (`midi-string-ensemble-1` instead of five string parts), use
`midi-brass-section` for background brass chords, and use **voices** (`V1:`/`V2:`) for divisi inside one part. A part
that only plays early in the cue still holds its channel unless valda can share it. Don't count on that.

## Seating, balance and mix

| Part | `(pan)` | `(track-vol)` |
|---|---|---|
| Violins / string melody | 30 | 70 |
| Violas, second strings | 45 | 60 |
| Cellos / low strings | 65 | 70 |
| Contrabass | 72 | 65 |
| Flute, oboe, clarinet | 45–55 | 55–65 |
| Horns | 38 | 65 |
| Trumpets | 58 | 60 |
| Trombones, tuba | 68 | 65 |
| Timpani, taiko | 50 | 70 |
| Harp, celesta | 25 | 60 |
| Choir | 50 | 55 |
| Synth pads/fx | 50 (or 20/80 for width) | 40–50 |
| Percussion (ch 10) | default | 70 |

These `(track-vol)` values are for 8–13 parts at ff (the templates measure −3 to −5 dB peak). With fewer parts, raise them by
about 10. **Always run `scripts/levels.sh`**: valda's synth has no limiter, so a dense tutti clips. If it reports clipping,
scale every `(track-vol)` by 0.8. Set `(track-vol)` and `(pan)` once, at the top of each part. Use `(vol N)` (note velocity) for dynamics.
Velocity guide: **pp 25, p 40, mp 55, mf 70, f 85, ff 100**. Melody 5–10 above its accompaniment.
**Don't change `(track-vol)` mid-part.** It is emitted only with the part's next note (it can't swell a held note),
and inside voices it can move the part to a new channel.

## Techniques in GM terms

- **Legato line:** `(quant 100)` on pads and slow melodies, `(quant 90)` default, `(quant 50–60)` for spiccato/staccato ostinatos.
- **Crescendo / swell:** no hairpins in Alda. Velocity is fixed per note, so **re-articulate**: tremolo strings, repeated
  notes or a timpani roll with a stepped `(vol)` every beat or half bar. Also **add instruments** one by one (staggered
  entries) and put a reverse cymbal into the peak. A held whole note cannot get louder.
- **Diminuendo / fade:** the same in reverse. Step `(vol)` down on repeated chords, then drop parts out from the top down.
- **Timpani roll:** 32nds on one pitch, stepping `(vol)` up per beat. Put the hit on the root (or fifth) of the arrival chord.
- **Cymbal swell:** a 32nd crash roll (`o3 c+32*N`) with stepped `(vol)`, or `midi-reverse-cymbal`.
- **Reverse cymbal timing:** at `o4 c` the sample peaks about **1.5 s** after its start. Start it 1.5 s before the hit,
  i.e. `1.5 × BPM / 60` beats early (3 beats at 120 BPM, 2 beats at 80 BPM). Rest the remaining time.
- **Harp glissando:** a fast diatonic run (`16`/`32`) over 1–2 octaves, ending on a chord tone at the downbeat.
- **Octave doubling:** melody in horns `o3`–`o4` + cellos in unison (warm), or violins + flute 8va (bright).
  Climax: violins `o5` + trumpets `o4` + horns/cellos `o3`.
- **Bass weight:** contrabass + tuba (or contrabass + low piano) an octave below the cellos. Timpani on the root at hits.
- **Divisi in one part:** voices. Restate `oN`, the duration and `(vol)` at the start of each voice and again after `V0:`.

## Orchestral percussion on `midi-percussion` (GM map, channel 10)

| Sound | Alda | Use |
|---|---|---|
| Concert bass drum (acoustic BD) | `o1 b` | big downbeat hits, with timpani |
| Bass drum 1 | `o2 c` | tighter impact |
| Snare | `o2 d` | military/march, rolls as `d32*N` |
| Crash | `o3 c+` / `o3 a` | arrivals. Rings on: no choke |
| Ride / suspended cymbal roll | `o3 d+32*N` | soft shimmering swell |
| Splash | `o3 g` | light accent |
| Open triangle | `o5 a` | sparkle, fantasy, comedy |
| Tambourine | `o3 f+` | festive/medieval |
| Low floor tom | `o2 f` | tribal/war drums (with taiko) |

There is no GM gong or tam-tam. Use a low crash plus a low piano note plus `midi-tubular-bells`, or `midi-reverse-cymbal`.

```alda
# A 4-bar swell into a hit: tremolo strings re-struck with rising vol, timpani roll, crash at the arrival
(tempo! 80)
midi-tremolo-strings:
  (quant 100) (pan 40)
  (vol 30) o3 d2/a/>f< (vol 40) d2/a/>f< | (vol 52) d2/a/>f< (vol 65) d2/a/>f< |
  (vol 80) d2/a/>f< (vol 92) d2/a/>f< | (vol 100) o3 d1/a/>d/f<
midi-timpani:
  r1*2 |
  (vol 35) o2 a32*8 (vol 50) a32*8 (vol 65) a32*8 (vol 80) a32*8 |
  (vol 100) o2 d4 r4 r2
midi-reverse-cymbal:
  r1*2 | r2 (vol 90) o4 c2 | r1          # 1.5 s at 80 BPM = 2 beats early
midi-percussion:
  r1*3 | (vol 100) o1 b4/>>c+<< r4 r2
```
