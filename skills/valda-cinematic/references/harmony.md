# Cinematic harmony, spelled in Alda

Film harmony runs on **color and motion between chords** more than on functional cadences. A few moves carry most of
the emotional meaning. Chord voicings below are root position or voice-led around `o3`–`o4`. Transpose by changing the letters
(or use `(transpose N)` on the part). For scale and chord formulas, see valda-music's `references/theory.md`.

**Voicing rules:** open (wide) spacing low, close spacing high. Below `o3 c` use only roots, fifths and octaves (a third
down there turns to mud). Double the root, not the third. Move inner voices by step (fewest notes). Pedal tones in the
bass under changing chords are the cheapest way to create tension.

## Progressions by mood

| Mood | Progression (roman) | Example key | Why it works |
|---|---|---|---|
| Epic, fateful | i–VI–III–VII | D minor: Dm B♭ F C | minor tonic, big major chords, no leading tone, loops forever (Zimmer school) |
| Epic, tragic | i–VI–iv–V (or i–VI–VII–i) | D minor | classic tragic loop. V adds a darker pull |
| Heroic, triumphant | I–♭VII–IV–I | C: C B♭ F C | Mixolydian "rock hero" cadence, bright with no leading tone |
| Heroic, grand | I–♭VI–♭VII–I | C: C A♭ B♭ C | the "victory" cadence: a borrowed ♭VI and ♭VII lift into I |
| Wonder, discovery | I–II (Lydian) | C: C D | the ♯4 in II (F♯) floats. Fantasy and flight |
| Wonder, sci-fi, awe | I–♭VI or I–III (chromatic mediants) | C: C A♭, C E | one common tone and two moving notes: a "new world" |
| Bittersweet, nostalgia | I–IV–iv–I | C: C F Fm C | minor iv borrowed from minor. Instant tears |
| Tender, intimate | I–V/7–vi–IV with sus | C | pop-familiar, but voiced in strings with suspensions |
| Sad, elegy | i–v–VI–iv / lament bass | A minor | descending bass by steps (lament tetrachord) |
| Unease, villain | i–♭vi (minor mediant), hexatonic pole I–♭vi | C: C A♭m | the "uncanny" move (C E G → A♭ C♭ E♭): no common tone |
| Dread, suspense | i over a pedal, iø7, tritone pairs | any | the pedal delays resolution, and tritones never settle |
| Mystery, noir | line cliché i–i(maj7)–i7–i6 | C minor | one inner voice descends chromatically |

## The moves, as code

```alda
# Epic minor loop (D minor): i–VI–III–VII
piano: (tempo! 80) o3 d1/f/a | d/f/b- | c/f/a | c/e/g
```

```alda
# Heroic I–bVII–IV–I, then the victory cadence I–bVI–bVII–I (C major)
piano: (tempo! 80) o3 g1/>c/e< | f/b-/>d< | f/a/>c< | g/>c/e< |
  g1/>c/e< | a-/>c/e-< | b-/>d/f< | g1/>c/e<
```

```alda
# Chromatic mediants from C: up to E (LP, bright awe), to Ab (PL, sublime), to Eb (RP), and the hexatonic pole Ab minor (uncanny)
piano: (tempo! 70) o3 g1/>c/e< | g+/b/>e< | g/>c/e< | a-/>c/e-< | g/>c/e< | g/b-/>e-< | g/>c/e< | a-/>c-/e-<
```

```alda
# Lydian wonder: I–II–I with the #4 in the melody (C lydian)
piano:
  V1: (vol 70) o5 e2 f+2 | g2 f+4 e4 | d1 | e1
  V2: (vol 55) o3 c1/g/>e< | d/a/>f+< | d/a/>f+< | c/g/>e<
  V0:
```

```alda
# Bittersweet I–IV–iv–I (minor iv): only one note moves (a -> a-)
piano: (tempo! 66) o3 g1/>c/e< | a/>c/f< | a-/>c/f< | g/>c/e<
```

```alda
# Pedal point: a C pedal under a changing harmony. The tension rises until the cadence frees the bass
piano:
  V1: (vol 50) o2 c1~1~1 g1
  V2: (vol 60) o3 g1/>c/e< | a/>d/f< | a-/>c/f< | g/b/>d<
  V0:
  o2 c1/g/>e<
```

```alda
# Suspensions: sus4 -> 3 and sus2 -> 3 on strong beats (drama, prayer)
piano: (tempo! 60) o3 c2/g/>f< c/g/>e< | a2/>e/b< a/>e/>c<< | f2/>c/g< f/>c/a< | g2/>d/g< g/b/>d<
```

```alda
# Lament bass (descending tetrachord) with a Picardy third at the end (A minor -> A major)
piano: (tempo! 60) o2 a2/>e/a/>c<< g+/>e/b< | g/>e/b< f+/>d/a< | f/>d/a< e/>e/g+/b< | a1/>e/a/>c+<<
```

```alda
# Dread: tritone pairs, a semitone cluster, the minor-major 7th (noir/Hitchcock), and whole-tone planing
piano: (tempo! 60) o3 c1/f+ | c/c+/d/d+ | c/e-/g/b | c2/e/g+ d/f+/a+ | e/g+/>c< f+/a+/>d< | c1/e/g+
```

```alda
# Noir line cliché: Cm, Cm(maj7), Cm7, Cm6. One inner voice falls by semitones
piano: (tempo! 72) o3 g1/>c/e-< | g/b/>e-< | g/b-/>e-< | g/a/>e-<
```

```alda
# Planing: parallel major triads over a pedal (fantasy, ancient, choral)
piano: (tempo! 72)
  V1: (vol 50) o2 d1~1
  V2: (vol 65) o4 d4/f+/a c/e/g d/f+/a e/g+/b | f2/a/>c< e/g+/b
  V0:
```

## Melody tips that sound "film"

- **Wide leaps up, steps down.** Open a heroic theme with a rising 4th, 5th or octave, then fill the gap stepwise.
- **Hold the color note.** Put the ♯4 (Lydian), ♭6 (minor iv) or 9th on a long, strong beat.
- **Sequence it.** Repeat a 2-bar motif a step or a third higher to build. Fragment it (keep the first 3 notes) to build tension.
- **Leitmotif = 3–6 notes with a distinctive rhythm.** Change its mode (major → minor), tempo (augment for tragedy),
  register and orchestration to tell the story. Don't change its contour.
- **Never quote** an existing film theme. Use the techniques, not the tunes.
