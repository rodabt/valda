# Song structure for drum arrangements

## Typical forms (bars in 4/4)

| Style | Form |
|---|---|
| Rock | intro 4–8 · verse 8–16 · chorus 8 · verse 8–16 · chorus 8 · bridge/solo 8–16 · chorus 8–16 · outro 4–8 |
| Pop | intro 4 · verse 8 · pre-chorus 4 · chorus 8 · verse 8 · pre 4 · chorus 8 · bridge 8 · (breakdown chorus 8) · chorus 8 · outro 4 |
| Pop-punk | count-in 1 · intro 4 · verse 8 · chorus 8 · verse 8 · chorus 8 · half-time bridge 8 · chorus ×2 8+8 · hit |
| Hard rock / classic metal | intro riff 8 · verse 16 · pre 4–8 · chorus 8 · verse 16 · pre · chorus · solo 16 · chorus · outro riff 8 |
| Thrash | intro 8 · verse 16 (skank) · pre 8 (half-time or gallop) · chorus 8 · verse · chorus · breakdown 8 · solo 16 (double kick) · chorus · ending |
| Metalcore | intro 8 · verse 16 (blast or double kick) · chorus 8 (half-time + open crash) · verse · chorus · breakdown 8–16 · chorus · outro |

When the user gives the form, use it exactly. Otherwise propose one from this table and state the total time
(seconds = bars × 4 × 60 / BPM).

## What the drums do per section

| Section | Timekeeping | Kick/snare | Energy |
|---|---|---|---|
| Intro | Often different from the verse: toms (`tomGroove`), hats only, a full-band riff hit, or 1 bar of stick count-in (`o1 g` quarters) | Sparse, or matching the riff | Sets the tempo |
| Verse | Closed hats (`HH`) or cross-stick | Simple, leaving room for vocals | 60–75 % `(vol)` |
| Pre-chorus | Change one thing: kick on all quarters, toms in place of hats, half-time, or 8th snares building | Building | Rising. End with a build or a fill |
| Chorus | Ride, open hats, or crash-ride (crash on every quarter) | Fuller and busier | 85–100 % |
| Bridge | Something new: half-time, tom groove, or drop out for 4 bars then come back in | | Contrast |
| Solo | Same as chorus, or double-time | | High |
| Breakdown (metal) | China on the quarters, half-time snare on 3 | Kick doubles the guitar chugs | Heavy, not fast |
| Outro | Chorus groove, then the ending (`endingBig`, `endingRit`), or a fade with falling `(vol)` | | Resolve |

## Phrasing and variation

- Think in **4-bar phrases**: groove, groove, groove, variation/fill. In an 8-bar section, bar 4 gets a small
  variation (`fillBeat4`, or an open hat on the "&" of 4) and bar 8 gets the fill into the next section.
- **Change one thing at a time** between sections (hats → ride, or adding 16ths on the kick). Changing everything at once sounds like a different song.
- The second verse and chorus can be busier than the first. The last chorus is the biggest (crash-ride, double kick in metal).
- Before the last chorus: the biggest fill, a `buildUp`, or 1–2 bars of silence or `fillStop`.

## The crash layer

Fills are written as replacement bars, and grooves can't be layered by nesting voice groups (nested `V1:` inside a
voice gives wrong timing). Crashes therefore go in a **second percussion part** that jumps to markers:

```alda
rock8 = [
  V1: (vol 70) o2 f+8 f+ f+ f+ f+ f+ f+ f+
  V2: r8 r (vol 90) o2 d r r r d r
  V3: (vol 92) o2 c8 r r r c c r r
  V0:
]
fillToms = (vol 95) o2 d16 d d d o3 d d d d c c c c o2 f f f f

midi-percussion "kit":
  %intro   rock8*3 fillToms
  %verse   rock8*3 fillToms
  %chorus  rock8*4

midi-percussion "crashes":
  (vol 100) o3
  @verse   c+1
  @chorus  c+1
```

- Markers are defined in the kit part (`%name`), and the crash part must come **after** it in the file.
- Add a marker anywhere a crash is needed, not only at section starts: `%verseB` after a mid-verse fill.
- Want a kick under each crash? The groove usually already has a kick on beat 1. If it doesn't, add `o2 c1/o3 c+` in the crash part.
- `valda play -f song.alda --from chorus` uses the same markers for auditioning sections.
- Both parts play on MIDI channel 10, so `(track-vol)` is shared. If you set it, use the same value at the top of both parts.
  When the two parts disagree, the channel volume jumps every time the other part plays, which can clip the mix.

## Count-ins and tempo

- **Stick count-in:** `countIn = (vol 90) o1 g4 g g g`, one bar before the intro (or two bars of half notes then quarters: `g2 g g4 g g g`).
- Use one `(tempo! N)` at the top of the score. For a tempo change at a section (a half-time bridge is usually
  written as half-time, not as a tempo change), put `(tempo! N)` right after that section's marker in the kit part.
