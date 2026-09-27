# Redesign tokens

The redesign's colours and typeface live beside the current ones so screens can move to them
one at a time. Nothing draws them until a screen is changed on purpose.

## Colours

`BrandPalette.Redesign` in `Sources/Uttrflow/Brand/BrandPalette.swift` holds them. A
`BrandTone` is a solid dark/light pair; a `BrandLayer` is a tone drawn at an opacity, for the
translucent card film, hairline, sidebar island and secondary text of the dark appearance.

| Token | Dark | Light |
|---|---|---|
| `pageGround` | `#0B0C10` | `#F2F1EC` |
| `windowGround` | `#0C0D14` | `#F2F1EC` |
| `cardFill` | white at 3.5% | `#FFFFFF` |
| `hairline` | white at 8% | `#DEDCD4` |
| `sidebarIsland` | `#100F1C` at 92% | `#12101E` (stays dark) |
| `textStrong` | `#FFFFFF` | `#101316` |
| `textSoft` | white at 72% | `#5C6866` |
| `textQuiet` | white at 55% | `#5C6866` |
| `dictationAccent` | `#5FE0D3` | `#128077` |
| `suggestionAccent` | `#C49BF5` | `#7A4FC4` |
| `clipboardAccent` | `#FFB05C` | `#B5650F` |
| `infoAccent` | `#6BB4F5` | `#1E6FC4` |
| `auroraStops` | `#7A3FD1` `#4B3FC0` `#1F8FB0` `#2FE0CF` | same |
| `dockGlass` | `#100D1E` at 72% | `#FFFFFF` at 90% |
| `dockGlassEdge` | white at 14% | `#101316` at 10% |
| `dockShadow` | black at 50% | `#101316` at 22% |
| `dockMeter` | `#FFFFFF` | `#128077` |
| `avatarInk` | `#08131A` | same |
| `heroGround` | `#0E111A` | `#FFFFFF` |
| `waveformInk` | white at 88% | `#101316` at 79% |
| `controlFill` | white at 6% | `#101316` at 4% |
| `controlEdge` | white at 14% | `#101316` at 14% |
| `ringTrack` | white at 10% | `#101316` at 10% |
| `cardEdge` | white at 8% | none |
| `neutralAccent` | `#A7ACB8` | `#5E6470` |
| `badgeInk` | `#AFF3EC` | `#0E645D` |
| `fieldWell` | black at 25% | `#101316` at 4.5% |
| `primaryFill` | `#FFFFFF` | `#101316` |
| `primaryInk` | `#0B0C10` | `#FEFEFE` |
| `destructiveInk` | `#FF8A8C` | `#B0161A` |
| `quietFill` | white at 8% | `#101316` at 7.2% |
| `sheetGlass` | `#121020` at 96% | `#FEFEFC` at 93% |
| `toastGlass` | `#121020` at 90% | `#FEFEFC` at 93% |
| `scrim` | `#05050A` at 55% | `#F2F1EC` at 55% |
| `floatShadow` | black at 70% | black at 12% |

Text tones clear 4.5:1 on the page and on a card; accents clear 3:1 there, the bar for marks.
The floating button's ink clears 4.5:1 on its glass and the meter 3:1, measured over the
same dark and light desktops `Docs/app-dock.md` uses.
`BrandPaletteTests` measures both.

## Typeface

Headings use Outfit, a variable font under the SIL Open Font License 1.1. The font file and its
licence ship together in `Sources/Uttrflow/Resources/Fonts/`, as the licence requires.
`BrandFont` registers it for the process at launch and falls back to the system font when the
file is missing or registration fails.
