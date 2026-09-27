# Quick panel: measurements and platform traps

What `Sources/Uttrflow/Panel/QuickPanelView.swift` relies on that the code alone does not show.
`Docs/panel.md` describes the panel's behaviour; this file holds the numbers and the AppKit
and SwiftUI traps the view is written around.

## Focus between the search field and a sheet

Two `@FocusState` bindings that both ask for focus are not a contest the newer one wins. The
search field is the panel's first responder from the moment it opens and keeps focus until
something releases it, so `isSheetFocused = true` on its own sets a flag that never becomes
focus: the sheet shows its placeholder while every keystroke filters the list behind it.
Measured three seconds after a sheet opened, by typing nine characters and finding all nine in
the search field.

Releasing the search from the panel's own `.task` does not fix it either, because that release
lands *after* the sheet field appears and takes the field's focus down with it; the keystrokes
then go nowhere at all. The working order is both writes in the sheet field's `onAppear`, with
the release first and the claim last — and the claim on the *next* turn (`Task { … }`), since a
focus request made while SwiftUI is still assembling the update that puts the field on screen
is applied against a responder chain the field is not yet in and is dropped silently.

The panel's `.task(id: presentation.sheet == nil)` does the reverse: when the sheet closes it
releases the sheet's focus and hands the search field back its caret.

A sheet resumed on reopen is the exception to "`onAppear` claims it": the panel's view is built
once, so a sheet open when the panel hid never left the tree and its field does not appear
again. The `.task(id: openCount)` that runs on every show therefore checks the snapshot: with a
sheet that takes typing it releases the search and claims the sheet field after a yield, and
only otherwise gives the search its caret (#920).

## Hover while another application is frontmost

`.onHover` only reports while Uttrflow is the active application, and the quick panel never
activates it — the insertion path declines while Uttrflow is frontmost, so a panel that
activated could not paste anywhere. The symptom is rows that never light up under the pointer
and one row that keeps its hover for ever because the matching exit never arrived.

`PointerWatch` wraps an `NSTrackingArea` with `.activeAlways`, which tracks regardless of
activation, and `.inVisibleRect`, which keeps the tracked rectangle in step with a scrolling
row. Its `hitTest` answers `nil` so the row behind it still takes the click.

## Right-click without an `NSMenu`

`.contextMenu` hands the menu to AppKit, which draws it in the system's grey and metrics with no
icons; every other pixel of the panel is drawn by the view. `RightClickWatch` catches the click
instead and the panel opens its own menu. Two details matter:

- It is an **overlay, not a background**. The row is a `Button`, the button's own view is in
  front, and hit testing stops at the first view that claims the point — behind the row the
  catcher is never asked, and the right-click reaches the button, which latches into its pressed
  shade and stays there.
- `hitTest` claims only `.rightMouse*` events and a left click carrying ⌃ (macOS does not
  translate ctrl-click for you). Everything else answers `nil` and falls through to the row, so
  the left click that pastes a clip is untouched.

## Row identity across grouping

The list is one `ForEach` over sections whether browsing (one unnamed run) or searching (one run
per heading). A row's `.id` is keyed by section as well as by clip: an explicit id is a promise
to SwiftUI that this is the same view as before, and a row that kept its id while moving from
the flat list into a heading kept its old rendering too — unringed and unfilled while the
presentation said it was selected.

## Menu placement

The ⋯ menu is anchored to the panel's trailing edge below the chips, not to the row whose ⋯
was pressed. A menu pinned to a row inside a scroll view is clipped near the bottom of the list
and would have to measure the remaining room and flip; the menu's header names the clip
instead, so there is never a question of which row it means.

## Sizes

| Value | Points | Why |
| --- | --- | --- |
| Panel | 420 × 560 | The approved design; the view fills the window rather than pinning this |
| Corner radius | 16 | |
| Search field height | 42 | Taller than the microphone beside it, so the search leads the panel |
| Control height | 34 | The microphone button |
| Row height | 34 | Every row the same height, so arrow-key counting stays right |
| Chip padding | 9 | The filter segments and the collection chips share one row of a 420-point panel |
| Thumbnail | 34 × 24 | |
| Menu width | 200 | |
| Sheet width | panel − 56 | A cap, so the sheet shrinks with a narrower panel |

## Palette contrast

The panel is tinted glass that follows the appearance: `BrandPalette.Redesign.Panel.glass`
over the system material, with the aurora's four stops swept, blurred and drawn at 0.22 across
its top edge. Every colour is a `Panel` token resolved per appearance.

| Colour | Dark | Light | Contrast on the glass, dark / light |
| --- | --- | --- | --- |
| `panelLabel` | `F4F4F6` | `101316` | 17.9 / 17.6:1 |
| `panelLabelSoft` | `8B90A0` | `5C6866` | 6.2 / 5.5:1 |
| `panelLabelDim` | `7A7F8E` | `6D6481` | 4.9 / 5.2:1, and 4.5:1 on the ⋯ menu's glass, the tightest ground for words |
| `panelGhost` | `656E80` | `8A8F9C` | 3.8 / 3.1:1, a mark's floor rather than a word's; never the only signal on a row |
| `panelAccentBright` | `5FE0D3` | `128077` | 12.2 / 4.5:1 as a foreground |
| `panelAccentText` | `04332F` | `FFFFFF` | ink on the accent fill: 6.1 / 4.8:1 |

The glass is measured over a mid-grey desktop in each appearance, as the floating button's is.
`RedesignTokenTests` computes every ratio here, so a palette edit that drops a word below 4.5:1
— or the ⋯ glyph below 3:1 — fails the build. The ⋯ menu's glass is `161424`, a step darker
than the design's `181626`, because that is what keeps the dim tone at 4.5:1 on it.

The selection ring is `panelAccent` at 0.38 over a 0.08 wash; at 1.5 points and full strength
the ring was brighter than the clip it pointed at. An active collection chip is a 0.16 wash with
a 0.35 border for the same reason. The kind filters are one segmented control whose chosen
segment is a solid pill, white when dark and ink when light. Delete takes `panelDestructive`
only under the pointer.

## The window: key, never main

`QuickPanel` is a `.nonactivatingPanel` with `canBecomeKey` true and `canBecomeMain` false.
The mask is what makes keyboard input possible without activation; key lets the search field
hold the caret; main is what drags application activation along behind it, and activation is
the thing that must not happen. The paste path refuses to insert while Uttrflow is frontmost
(`PasteboardTextInsertionEngine.canInsert()` is `!focus.isSelfFrontmost()`, which compares
`NSWorkspace.shared.frontmostApplication` to this process). Activating to get keys would not
throw or warn; Return would simply do nothing and the clip would stay on the clipboard.

Measured with the panel open over TextEdit and answering ↓ ↑ Return: frontmost stayed
`com.apple.TextEdit` for the whole session. `NSApp.isActive` reads `true` in that state; it is
AppKit's own bookkeeping, not the system's idea of frontmost, so anything that needs to know
whether pasting will work must ask `NSWorkspace`.

The controller shows the panel with `orderFrontRegardless` then `makeKey`, never
`makeKeyAndOrderFront` or any form of `activate`; it hides with `orderOut` and activates
nothing on the way out either, because the application underneath never stopped being
frontmost.

Every line of `configurePanel()` follows from the same rule: `becomesKeyOnlyIfNeeded` false
(the search field must be typeable at once), `hidesOnDeactivate` false (the app is never
active), level `.statusBar` with `.canJoinAllSpaces` and `.fullScreenAuxiliary`,
`animationBehavior` `.none` (three keystrokes cannot feel instant from behind a fade), and no
`.resizable` in the style mask, so the hosting view is the border's one owner.

## What the open waits for: nothing

The shortcut shows the window and makes it key with no `await` in between, and everything the
panel needs is asked for afterwards. The order was the other way round until #860, and it cost
the user their keystrokes: the panel is not key until it is on screen, so the letters typed
straight after ⇧⌘V — the usual gesture is ⇧⌘V and then an alias — were inserted into whatever
document was in front, and the panel's search began without them.

What was being waited on had nothing to do with drawing a window: the store's list, one whole
file read per picture in that list (#576), the Accessibility and frontmost checks, and the
microphone check. Measured against a real `ClipboardStore` over a history of 220 clips of which
20 are 5120 × 2880 screenshots, warm, three rounds:

| On the old path to `show` | CPU |
| --- | --- |
| The list, the pictures folder, and one read per picture | 4.3–4.7 ms |
| Recording one fresh 5K screenshot, which a read arriving behind it waits for | 6.4–7.2 ms |

Single-digit milliseconds is the *quiet* case, and it is not what the order cost. A read of the
list has no upper bound, because it queues behind whatever write the store is doing — the
`markUsed` rewrite from the last paste (#578), or the record of the copy just made. Two of the
waits behind that record have no bound at all: `NSPasteboard` reads of promised data wait for
the application that copied, which has been seen to take 70 s (#895), and a long grapheme
cluster keeps classification busy for minutes (#896).

So the open now does this, and in this order:

1. `PanelSnapshot.opening(now:resuming:)` — a panel with no list, marked `isAwaitingList`.
2. `QuickPanelController.show(_:)` — `orderFrontRegardless` then `makeKey`, synchronously.
3. The catch-up, started and not awaited, so the copy just made is never on this path.
4. Accessibility, the microphone and the pictures folder.
5. The list, by `refreshPanelIfOpen()` — the same path a copy arriving takes.

Two things follow from step 5 being shared. The caught-up clip is not dropped any more: it
arrives through a refresh that finds the window already visible, where before it was thrown
away by the `isVisible` guard while the panel was still being built. And because two reads of
the store can now be in flight at once, the app counts them (`panelReads`) and a read that
started earlier never installs its list over a newer one — otherwise the copy the refresh had
just shown would disappear again.

A second press of the shortcut needs no flag of its own: the window is visible from step 2, so
the guard at the top of `toggleQuickPanel()` closes it. Nothing an open awaits is written into
a panel it no longer owns, which `QuickPanelController.opens` decides.

What the panel shows between step 2 and step 5 is an empty list with nothing said about it. See
`Docs/panel.md` on why it says nothing rather than "Nothing copied yet", and why the place the
user left is restored by the list arriving rather than by the window appearing.

The gap that is left is one turn of the main queue: Carbon delivers the shortcut on the main
run loop, and `toggleQuickPanel()` runs when the task awaiting the monitor's stream is
resumed. Closing that too would mean showing the window from inside the Carbon handler.

## Dismissal

`windowDidResignKey` is deliberately empty. Losing key is not the user going somewhere: a
notification banner, a Bluetooth prompt, a permission sheet or a screenshot all take key for a
moment, and closing on it made the panel vanish mid-use with the next keystrokes landing in
whatever was behind. The panel closes instead on a global mouse-down outside its frame or on
another application activating (`NSWorkspace.didActivateApplicationNotification`, ignoring
Uttrflow itself, which is the main window opening from the panel). Global mouse monitors need
no permission, so this works before Accessibility is granted.

## Position

The panel opens on the screen the pointer is on (`NSScreen.main` belongs to another
application's key window here), where the user last dragged it on that display, else in its
top-right corner. Each display keeps its own origin, keyed by its `NSScreenNumber`, in one
`UserDefaults` dictionary (`PanelSpots`), so a spot on one display never places the panel on
another. The size is the design's on every open; a drag-resize lasts only while the panel is on
screen.

`windowDidMove` compares the frame origin to `placedOrigin`, the origin `show(_:)` last set,
rather than using a flag: AppKit delivers the notification on a later pass of the run loop, by
which time a flag has been cleared and the panel's own placement is indistinguishable from a
drag. A resize from the left or bottom border moves the origin too and sets `placedOrigin`
through `onResize`, so a resize is remembered as exactly nothing. While dragging, the origin is
clamped to the visible frame of the screen the panel is on, not the pointer's, because a
borderless panel gets none of AppKit's protection and goes clean under the menu bar.

## What VoiceOver is told

Every notice the panel shows is also announced: the three copy-only notices ("Copied — press
⌘V…"), a refused write, and a picture that is no longer on this Mac. So is the undo offer after a
delete, spoken as "Deleted. Press Command-Z to put it back." A copy-only choice closes the panel
2.5 s later, which is sooner than VoiceOver focus reaches the notice bar, so drawing it is not
enough.

`PanelPresenter` decides the words (`PanelPresentation.announcements`); the controller posts each
line once when it appears during an opening, then posts it again if the panel closes and reopens
with the same notice. Unrelated redraws do not repeat it. Each post is an
`AccessibilityNotification.Announcement` at high priority so the panel closing does not cut it off.

A row's VoiceOver hint follows the same decision as Return: "Pastes where you were typing" when a
paste can be attempted, and a hint saying it copies when the panel knows it can only copy.

## After the panel has closed

Choosing a clip closes the panel before the paste, because insertion declines outright while
Uttrflow is frontmost. So whatever goes wrong after that has no panel to say it on. The floating
button says it instead, and VoiceOver hears it as an announcement at high priority, because
that is where a dictation's outcome already appears and where the user's eye goes when nothing
arrives.

`PanelPasteReport.after(_:)` in `UttrflowUX` is the one decision, for text and pictures alike:

| What happened | What is said |
| --- | --- |
| Text seen to arrive, or a target that cannot say | nothing, as for a dictation |
| Text sent and never seen to arrive (`.unconfirmed`) | "Inserted — not confirmed", the dictation's own words |
| Text left on the clipboard, or every strategy refused | "Copied — press ⌘V" |
| A picture on the clipboard whose ⌘V was refused | "Copied — press ⌘V" |
| A picture whose file went before Return | "That picture is no longer on this Mac" |

A dictation under way owns the floating button, so the report is spoken but not drawn over it.
The drawn report stays for as long as a dictation failure does and then gives the button back.
When the floating button is turned off, the announcement is the only surface.
