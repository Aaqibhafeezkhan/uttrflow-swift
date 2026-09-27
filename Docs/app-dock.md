# Dock button: measurements and traps

What `Sources/Uttrflow/Dock/DockView.swift` and `DockPanelController.swift` are drawn to, and
the two things that are not obvious from the code.

## Forms and sizes

| Form | Size (points) | Notes |
| --- | --- | --- |
| Resting grip | 9 × 34 | Three dots drawn straight on the desktop; no slab, because a slab around nine points reads as a box somebody forgot to delete. Six points of invisible hoverable padding all round. |
| Hovered | orb 30 + hint 30 high | The orb keeps the grip's side so it stays under the pointer |
| Listening | 32 high | The meter and a running clock on tinted glass, the clock on the anchored edge; no mark |
| Working | 40-point orb | Three bars rising and settling in turn, for as long as there is work left |
| Inserted | 26-point disc | A teal return arrow inside the ring; a success needs no words, the text is already in the document |
| Nothing heard, too short | 28 high, words up to 200 wide | The struck level with its sentence, readable at rest; a too-short hold says to hold longer |
| Copied, not typed | 28 high | ⌘V and "Copied, not typed" at rest, kept up as long as a failure; the reason and the Fix button under the pointer |
| Microphone off | 28 high | The warning disc, "Microphone is off" and a trailing Fix; the full sentence under the pointer |
| Blocked | 300 wide, at least 40 high | The only wide form, so after a run of discs it is unmistakably asking for something |
| Speech model loading | 300 wide, at least 40 high | The blocked form with an hourglass, in place of the resting grip for as long as the load runs. See `Docs/startup.md` |

`noticeMaxWidth` (300) applies to the blocked form alone. A single width applied to every
form made the listening pill 286 points wide on every dictation, for a state it never entered.

Every form but the resting grip sits on the same glass: the system material under
`BrandPalette.Redesign.dockGlass`, violet-black at 72% when dark and white at 90% when light,
with a one-point `dockGlassEdge` hairline. Words and glyphs on it are `textStrong`, white when
dark and ink when light.

The blocked form's message wraps to at most `noticeMaxLines` (3) lines and the form grows to
hold it; the recovery button sits under the words rather than beside them, so it never takes
width the message needs. At one line with no button the form is the 40-point capsule it always
was. `DockNoticeTextTests` measures every failure message at the view's font and wrap width and
fails when one would need a fourth line, and the whole notice is on the pointer as a tooltip.

## Meter

- Bars arrive at 20 Hz (`meterArrivalInterval` 0.05 s), the rate the controller polls the
  microphone. The tap hands over 4096 frames at a time, about twelve blocks a second, so
  polling faster only resamples the same number and polling much slower shows a meter that
  steps. The timer runs in `.common` mode, or a drag of the button to another corner freezes it.
- The row is redrawn up to 60 times a second at a fractional offset from `lastArrival`, not on
  arrival: twenty sideways jumps a second reads as stepping rather than flowing. In Low Power
  Mode or at serious thermal pressure it drops to the 20 Hz data rate and accepts the step, per
  `MotionBudget`; see `Docs/performance.md`.
- Meter width is fixed at 100 points; how many bars fit is a consequence of the width, and
  `DockBars.capacity` is held to cover it. The first and last 20% fade up from nothing, so bars
  enter and leave softly rather than at a hard edge.
- The clock beside it reads the time since the key went down as `0:04`, advanced by the
  meter's own 20 Hz arrivals so it adds no timer of its own. Once the cap is near the countdown
  takes its place, because the time left matters more than the time spent.
- `meterAmplitude` 0.9 keeps a loud syllable from touching the glass.
- Working is a 40-point glass orb whose three bars rise to full height and settle to 40% in
  turn, each 0.15 s behind the one to its left, over one second. It runs for as long as there
  is work left, which includes the wait for the application to take the words: transcribing,
  tidying and inserting are one wait to the person waiting, so they are one animation and one
  sentence. Under Reduce Motion the bars hold still at full height, per `MotionBudget`.
- It used to resolve instead — 0.34 s settling the row the voice left behind, then a 0.3 s
  spring folding the bars into a tick — on the reasoning that a loop is the animation of a
  wait with no end. The wait does have an end, but the animation reached it first: the tick
  landed 0.98 s after the key came up whatever the pipeline was doing, so on any dictation
  longer than a second the panel said the words were in while they were still being
  transcribed. It was not even the right tick — an SF Symbols `checkmark`, where the finished
  state draws its own. A tick is a claim about the words, and only
  ``DictationState/inserted`` may make it.

### Why the loud threshold is carried by opacity

The meter is one colour, `dockMeter`: white on the dark glass and dictation teal `#128077` on
the light. Quiet bars are drawn at `meterQuietOpacity` 0.62 and loud ones at full strength. An
earlier pair of teals could not carry the threshold by hue, collapsing to 1.05:1 on a dark
desktop, and opacity works on both grounds because it depends on neither.

## Inserted is a return arrow

`InsertedMark` is `ReturnArrow` — a 13-point return key on a 24-unit grid, a stroke down the
right side turning left into an arrowhead — drawn on over 0.26 s in dictation teal
`dictationAccent` inside the 26-point disc. It names the key that puts words in, which is the
thing that just happened.

It used to be a tick, `MarkTick`: one round-capped stroke on the mark's 100-unit grid in
`successInk` green. The design draws the return arrow, and a green tick was the one place the
dock spoke in a colour the rest of the redesign does not use. Before that it was the mark
opening into a check, which at 14 points in a 26-point disc read as an upside-down `u`.

## Colours

- `dockAccent` `#128077` is capped at 29% lightness so white 13-point text clears 4.5:1 on it.
  The mark's own teal is lighter than that and never carries text.
- The status colours are held to the same minimums on both desktops, measured with the WCAG
  formula against the glass over a light desktop (about `#EEEEEE`) and a dark one (about
  `#262626`), and checked by `DockContrastTests`:

  | Where | Colour | Against | Ratio | Needed |
  | --- | --- | --- | --- | --- |
  | Failure disc | `dockWarningFill` `#C25E00` | its white glyph | 4.29:1 | 3:1 |
  | Failure disc | `#C25E00` | light / dark glass | 3.70:1 / 3.53:1 | 3:1 |
  | Copied keycap text | `dockWarningInk` `#943C00` light, `#FFB05C` dark | keycap `#CDCDCD` / `#444444` (14% over light / dark glass) | 4.55:1 / 5.39:1 | 4.5:1 |
  | Inserted arrow | `dictationAccent` `#128077` light, `#5FE0D3` dark | light / dark glass | 4.13:1 / 9.43:1 | 3:1 |

  The bright `dockWarning` `#FF8D28` and `dockSuccess` `#34C759` measure 2.31:1 under white
  and about 2:1 on light glass, so the dock never draws with them.
- The panel's own `hasShadow` is off: AppKit draws a shadow around a transparent panel's
  opaque content, and every form already carries the one the design asks for. Two shadows
  around a nine-point grip is what made the resting button look boxed.
