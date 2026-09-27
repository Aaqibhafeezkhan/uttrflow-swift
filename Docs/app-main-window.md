# Main window: sizing and the clipboard demonstration

## Window sizing

`MainWindowController.makeWindow()` sets `hosting.sizingOptions = []`. `NSHostingView` reports
SwiftUI's ideal size as its `intrinsicContentSize` by default and AppKit resizes the window to
match, so the window grew and shrank as the user moved between pages. Measured before the
change: 1084 points tall on Home, 4458 on Account and 5461 on Insights. On Account the content
sat at the top of a window four times the height of the screen with everything below it blank.
The pages already scroll.

Default size is 1180 × 780 (900 × 620 is cramped once the rail carries four figures); minimum
760 × 500. The sidebar is a dark island floated 10 points off the window's edges: 88 points as
an icon rail (a 44pt target with room either side, wide enough that the zoom button, whose right
edge sits at 79 points, stays inside the island) and 232 with its names showing (six rows of
14-point text, the "Your words" heading and the account card), and the figures rail is 186. The two rails once shared a width, and at 76 points "Words per minute"
wrapped one word to a line and "2.7K" truncated to "2....".

The sidebar's expanded state is remembered in `UserDefaults` directly, not the settings store:
it is the window's own memory of how it was left, like the quick panel's position. With nothing remembered, as
on a first launch, the sidebar opens with its names showing.

## The clipboard demonstration

`ClipboardDemonstration` is drawn rather than recorded. A GIF is a few hundred kilobytes that
has to be re-recorded every time the panel's design moves, is wrong the moment somebody changes
their shortcut (this reads the real one), is soft on a Retina display, and cannot follow the
light or dark appearance.

It shows the whole gesture, ending with the words arriving in the document. A version that
stopped when the panel closed demonstrated a mechanism and left out the payoff.

- Loop: 8 seconds. Long enough to read the pasted line before it resets.
- Document width: 410 points. The finished sentence measures 383.6 points at the footnote
  size, regular and medium runs together, plus ten points of padding a side; a line that
  wrapped would read as a paragraph appearing.
- Layout: side by side while the document can hold its line, stacked otherwise. The card is
  offered a width, `onGeometryChange` records it, and
  `ClipboardDemonstrationMetrics.arrangement(forOfferedWidth:)` answers from it: side by side
  once 17 points of padding a side, 22 of gap, the document's 410 and 360 for the words all
  fit — 826 points — with the words widening to 460 and no further. At the 760-point minimum
  window, reserving 410 for the document leaves 294 for the words beside it, which is why the
  stacked form exists.
- `ViewThatFits` used to make that choice and does not any more. It asks every candidate how
  big it would like to be, and it was inside the clock's closure, so both arrangements were
  measured on every display frame — the subject of `Docs/performance.md`. The decision is
  width in, arrangement out, and the clock only draws.
- The animation is a pure function of the clock, so the page can redraw underneath it (on
  every keystroke in a search field) without the loop stuttering.
- Moves only while its window is key in the active app and some of the card itself is inside the
  scroll view's bounds and on a display, per `WindowAttention`, and only while
  `MotionBudget` finds no Reduce Motion, Low Power Mode or serious thermal pressure; otherwise
  it rests on the panel open with the address row chosen. Its clock wakes only when the drawing
  changes, and at most 30 times a second while the panel moves (`ClipboardDemonstrationMoments`).
  See `Docs/performance.md`.

## Colours

`Sources/Uttrflow/Brand/BrandPalette.swift` is the only place a colour is defined. It groups
every value by role — brand teal, brand purple, surfaces, lines, text tones and semantic
colours — each as a dark and light pair where the appearance changes it. Views name a palette
member, through aliases such as `Color.panelAccent` or `Color.mainBackground`; none writes a hex.
Where two views draw the same value they point at the same member, so the dock's live accent
and the quick panel's accent cannot drift apart. `NSColor.orbit(_:)` in `OrbitPalette.swift`
resolves a pair per appearance. `BrandPaletteTests` pins the primary teal and secondary purple.

Text that carries a status is drawn in an ink, never in a fill. The semantic fills — `warning`,
`success`, `recording` and the teal `deep` — are bright single values that sit near 2:1 on a
light card, which is fine for a dot, an icon or a filled button and unreadable as words. The inks
`Semantic.warningInk`, `successInk`, `criticalInk` and `Teal.ink` are pairs that clear WCAG AA's
4.5:1 on a card, on the ground and on their own 16% pill wash in both appearances, reached as
`Color.warningInk`, `successInk`, `criticalInk` and `accentInk` and through `MainTone.foreground`.
`SemanticInkContrastTests` computes those ratios, so a palette edit that drops one below 4.5:1
fails.

The three greys text is drawn in — `Text.primary`, `muted` and `dim` — clear 4.5:1 on all four
surfaces text sits on, the rail included, in both appearances. The rail is the darkest light
surface, and it carries the sidebar's version and badge counts, so it sets the floor: `dim` was
`A49DB3` at 2.16:1 there and is `6D6481` at 4.59:1, which puts it within a few steps of `muted`
on a light desktop. That is the room the ramp has, not a mistake — a fourth readable grey does not
fit between `muted` and the rail, so `Text.ghost` stays a mark rather than a word and is held to
3:1. `TextToneContrastTests` computes every one of those ratios and fails below the floor.
Increase Contrast is a separate question, tracked in #522; this floor is what the palette clears
before that setting is consulted.

## Home

`HomeDashboard` in `UttrflowUX` decides everything the page draws; the views only lay it out.

- **Mood.** The hour picks one of six parts of the day — 05–08 early morning, 08–12 morning,
  12–17 afternoon, 17–20 evening, 20–23 night, 23–05 late night — and with it the greeting
  ("Working late" after 23:00) and the picture in `Resources/Mood/` beside the hero.
- **Tiles.** Words today; the streak, days in a row with a dictation ending today or
  yesterday, since a day not over yet has not broken it; pace, pooled over every timed
  dictation kept; and the share left as dictated, the same measure the Dictation page uses:
  spoken words the clean-up kept as said, over every measured dictation kept. A figure with
  nothing measured behind it is a dash. The rings fill at 1,000 words, 7 days, 150 words a
  minute (an ordinary conversational rate) and 100%.
- **Recent activity.** The three newest dictations. The tag says what the clean-up did —
  "As dictated" or "N changes", counting corrections still standing and snippets — and a
  dictation that was never measured has no tag, so nothing is claimed about it.
