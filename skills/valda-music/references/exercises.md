# Practice exercises

A practice track has three jobs: keep time for the player, show the pattern clearly, and make stepping up the
tempo easy. Default structure:

1. **Count-in:** one bar of clicks (side stick `o2 c+`, or high woodblock `o5 e` with an accent on beat 1).
2. **Pattern** on the lead instrument, ascending then descending, ending on the root.
3. **Click** under the whole exercise in `midi-percussion` (quarters; add 8ths for subdivision practice).
4. Optional **drone or chord** (pad on the root, or the chord being arpeggiated) to train the ear.
5. Optional **tempo ramp:** the same block repeated at rising `(tempo! …)` with a one-bar rest and a click between.

Use `piano` as the default lead for scale demos. Use the user's instrument when they name one, and respect its range:
guitar E2–E6 (`o2 e`–`o6 e`), bass E1–G4, violin G3–A7, flute C4–C7, alto sax D♭3–A♭5 (concert).

## Click track building blocks

```alda
countIn = o5 (vol 90) e4 (vol 60) e e e
clickBar = o5 (vol 80) e4 (vol 55) e e e
clickBar8 = o5 (vol 80) e8 (vol 40) e (vol 55) e (vol 40) e (vol 55) e (vol 40) e (vol 55) e (vol 40) e
midi-percussion: countIn clickBar*4
```

Click `(vol)` is sticky inside the variable, so each click restates it.

## Scale, one or two octaves, up and down (8ths)

```alda
(tempo! 90)
piano:
  r1                                  # count-in bar
  (key-sig '(g major))
  o3 g8 a b > c d e f g a b > c d e f g4 |
  g8 f e d c < b a g f e d c < b a g4
midi-percussion:
  o5 (vol 90) e4 (vol 60) e e e
  [o5 (vol 80) e4 (vol 55) e e e]*4
```

Each line is 14 eighths plus a quarter = 2 bars, so 4 bars plus the count-in.

## Scale in diatonic 3rds (C major)

Pattern: 1-3, 2-4, 3-5, … up, then the mirror down.

```alda
piano:
  o4 c8 e d f e g f a | g b a > c < b > d c4 |
  c8 < a b g a f g e | f d e c d < b > c4
```

## Sequences (groups of 4 up the scale)

1-2-3-4, 2-3-4-5, 3-4-5-6 … Write each group out. Alda has no transposing-loop construct that follows the key,
so for long sequences generate the text, then check it.

```alda
piano:
  o4 c16 d e f d e f g e f g a f g a b | g a b > c < a b > c d < b > c d e c4
```

## Arpeggios through a progression (I–vi–IV–V in C, 8ths)

```alda
piano:
  o3 c8 e g > c e c < g e | a > c e a > c < a e c < |
  f a > c f a f c < a | g b > d g b g d < b
```

Each bar must end in the octave where it started. Count `>` and `<` per bar (here each bar balances).

## Interval drill (ascending 4ths, chromatic roots)

```alda
piano:
  o4 c4 f c+ f+ | d g d+ g+ | e a f a+ | f+ b g > c <
```

## Rhythm subdivision ladder (one pitch, quarters → 8ths → triplets → 16ths)

```alda
(tempo! 80)
piano:
  o4 c4 c c c | c8 c c c c c c c | c12 c c c c c c c c c c c | c16 c c c c c c c c c c c c c c c
midi-percussion:
  [o5 (vol 80) e4 (vol 55) e e e]*4
```

## Tempo ramp (same block at 80 → 100 → 120)

Use **`(tempo! …)` (global)**, so the click and the lead stay together. Put the ramp steps in the first part only.
The other parts must have the same total bar count, with rests during the breather bars.

```alda
lick = o4 c8 d e g a g e d
piano:
  (tempo! 80) r1 lick*4 r1
  (tempo! 100) r1 lick*4 r1
  (tempo! 120) r1 lick*4
midi-percussion:
  [o5 (vol 90) e4 (vol 60) e e e]*6
  [o5 (vol 90) e4 (vol 60) e e e]*6
  [o5 (vol 90) e4 (vol 60) e e e]*5
```

## Play-along with a drone

```alda
midi-synth-pad-warm:
  (quant 100) (vol 45) o3 d1~1~1~1/a
```

A held root plus fifth (four tied bars; a tied duration applies to the whole chord) under a modal scale (here D dorian) makes each mode's color easy to hear.
