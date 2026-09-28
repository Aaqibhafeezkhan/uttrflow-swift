# What each kind of application actually does with the words

Dictation, the clipboard paste-back and tab-to-complete all depend on things no part of
this codebase controls: whether another application publishes its focused field through
Accessibility, whether it takes a synthetic ⌘V, and whether it will say where the caret
is. Every one of those answers is a property of the receiving application, so the only
way to know it is to put words into that application and look.

This page is where those readings are collected. It replaces nothing: each row is a
measurement somebody already took and wrote down elsewhere, and the link on the row is
where the reasoning behind it lives. What this page adds is the one thing seven separate
documents could not — the ability to ask "in this kind of application, what works?" and
get an answer without reading all seven.

**Nothing here is inferred from the code.** A cell is a measurement or it is blank. Blank
means nobody has run that check on that application, not that the answer is no, and
`unknown` is written where a document says outright that something was tried and did not
settle. Reading a capability off the source would defeat the whole point of the page,
because every defect these documents record is a case where the code's own belief about
an application was wrong.

## The columns

One table per class of application below, one row per application. The class is the
table's heading rather than a column in it, since every row under a heading shares it.

| Column | Values | How it is measured |
|---|---|---|
| App | name, version, macOS version | the application's About window |
| Field | single-line, multi-line, rich editor, spreadsheet cell, secure, chat composer, address bar, shell | by inspection |
| Published | yes / no / only after `AXManualAccessibility` | `uttrflow-dev probe surface` |
| AX write | lands / refused / reports success, changes nothing / lands late | `uttrflow-dev insert --via accessibility` |
| Paste | lands / ignored / other shortcut fires / forwarded elsewhere | `uttrflow-dev insert --via paste` |
| Confirmed | landed / not reported / gave up | the same run's printout, with the caveat below |
| Full route | once / twice / nowhere | `uttrflow-dev insert`, no `--via` |
| Caret | right / wrong place / none | `uttrflow-dev probe surface`, plus looking at the screen |
| Value | yes / value only / no | `uttrflow-dev probe surface` |
| Marked text | yes / no | `uttrflow-dev probe ime` |
| Completion | correct / wrong characters / nothing | accept a suggestion in the application |
| Notes | line breaks, undo, right-to-left, anything surprising | |

### Three things to know before trusting a `--via` run

All three were found while writing this page, by reading
`Sources/uttrflow-dev/Insert.swift` and `Sources/UttrflowInput/SelectionWriter.swift`
against the column set above. Each means a forced route measures slightly less, or
something other, than it looks like it measures.

**"Reports success, changes nothing" no longer looks like success.** The column's value
is named after the defect as it was first seen, and the wording invites you to look for
`Inserted via accessibility` over an unchanged screen. You will not see that any more.
`SelectionWriter.replaceSelection(with:)` reads the field's value before the write and
again after it, and throws `insertionRejected` — "the field accepted the text and did not
change" — when they match, so `--via accessibility` into such a field **fails** and says
why. Record the column from that message, not from the screen.

One limit worth knowing while you do: the guard fires only when the field answers
`value()` both times. A field that will not say what it holds is trusted, deliberately —
a verification, not a precondition — so `reports success, changes nothing` and a genuine
silent success are indistinguishable there. That is the case #601 is about.

**`--via paste` does not print the confirmation timing.** `Insert` installs its
`report(_:)` printout — "words reached the caret after 0.42s" — only on the default route,
which it builds with `TextInsertion.coordinator(reporting:)`. Each `--via` case builds a
bare `TextInsertionCoordinator` instead, with no reporter. The confirmation itself still
runs, because `PasteboardTextInsertionEngine` returns the wait's answer as its
`InsertionArrival` rather than reporting it sideways — that is the fix
`Docs/insertion.md` records under "The answer is the return value, not a log line" — so
`--via paste` still prints the outcome as the arrival word on the `Inserted via …` line.
What it does not give is **how long** the words took. Fill the `Confirmed` column from a
`--via paste` run; take any timing from a full-route run.

**A `--via` run cannot measure a secure field.** All three `--via` cases construct
`TextInsertionCoordinator(strategies:)` without a `focus:`, and `focus` is what the
coordinator asks `focusedFieldIsSecure()`. With it nil the attempt is always marked
`intoSecureField: false`, whatever the field is, and the destination application is not
read either. So the password and PIN behaviour that `Docs/insertion.md` describes under
"Dictating into a field that hides what is typed" is reachable **only** from the full
route. A secure row measured with `--via` would record the guard as absent when it is
merely bypassed. #608 and #610 are the issues for that behaviour.

## Browsers

The engine is what matters here, not the brand: the two rows below differ on the one
column that decides whether anything can be drawn at all.

| App | Field | Published | AX write | Paste | Confirmed | Full route | Caret | Value | Marked text | Completion | Notes |
|---|---|---|---|---|---|---|---|---|---|---|---|
| Google Chrome | address bar | | | | | | | value only | no | | Whether the field itself is published is #101's to settle; nothing on this branch measures it. Window title answered; the selection is refused with `kAXErrorNoValue`, so half the context read comes back and half does not ([context-accessibility.md](context-accessibility.md)). `AXTextInputMarkedRange` is absent from the binary, checked against two control attributes that are present, so this is a real absence rather than a failed search ([predict-ime.md](predict-ime.md)) |
| Google Chrome 153, macOS 26.5.1 | single-line | only after `AXEnhancedUserInterface` | | | | | right | yes | | | With the full tree off, value and selection answer and every caret bound is a zero-size rectangle, so there is no placement. Chrome refuses `AXManualAccessibility` and applies `AXEnhancedUserInterface` while answering the write as not implemented; the suggestion loop turns it on for a caretless field once per process and off when suggestions stop. The caret was right about two seconds after the switch ([predict-reliability.md](predict-reliability.md)) |
| Google Chrome 153, macOS 26.5.1 | multi-line | only after `AXEnhancedUserInterface` | | | | | right | yes | | | As the single-line row. The text-marker selection (`AXSelectedTextMarkerRange` measured with `AXLengthForTextMarkerRange` from the field's start) agreed with `AXSelectedTextRange` across a line break, and is what the reader uses where the range is refused ([predict-reliability.md](predict-reliability.md)) |
| Google Chrome 153, macOS 26.5.1 | rich editor in a page | yes | | | | | right | yes | | | A code editor that renders its own text keeps an empty one-pixel textarea focused at the caret, so the field has neither a line nor a caret. The reader now reads the line off the rendered row the textarea sits on, split at the textarea's position, and takes that row's height for the caret; measured on a SQL-mode editor with `SELECT id, name FROM users WHERE` typed: line read whole, caret at the line's end, `inlineGhost`, about 8 ms a read ([predict-reliability.md](predict-reliability.md)) |
| Safari 26.5, macOS 26.5.1 | code editor in a page | yes | | | | | right | yes | | | WebKit widens the hidden textarea such an editor keeps at the caret to about 1 000 × 14 pt, so an empty text area one bare line tall (18 pt at most) is taken as the parked input too. WebKit also lays each highlighted run of a line straight into the tall editor rather than into a line element, so such runs share a row by their parent and their line band. Measured on a SQL-mode editor with `SELECT id, name FROM users WHERE` typed: line read whole, caret at the line's end, `inlineGhost`, about 8 ms a read warm ([predict-reliability.md](predict-reliability.md)) |
| Safari | address bar | | | | | | | | unknown | | Not settled either way. The marked-range walk could not resolve a focused element for a `WKWebView` at all, and walking the web view's subtree found no text element, so WebKit's own answer is unmeasured — Chromium's result does not speak for it ([predict-ime.md](predict-ime.md)) |

## Applications built on a bundled browser engine

Every failure in this class has the same shape: the application answers, and the answer
is not true. This is the class the paste route exists for.

| App | Field | Published | AX write | Paste | Confirmed | Full route | Caret | Value | Marked text | Completion | Notes |
|---|---|---|---|---|---|---|---|---|---|---|---|
| Claude desktop | chat composer | yes | reports success, changes nothing | | | | wrong place, now right | | no | | The write is accepted, answers `.success`, and does nothing. Believing the return value stopped the coordinator there, so the words reached neither the paste below nor the clipboard: the user watched the dictation happen and had nothing to paste. Every write is now read back ([insertion.md](insertion.md)). Separately, 609 consecutive turns were quiet for `nowhereToDraw` — every Chromium field answers the caret's glyph bounds with a zero-size rectangle at a false position, and the selection's text-marker range is what has real bounds ([predict-reliability.md](predict-reliability.md)) |
| Cursor | rich editor | no | | lands | | | | | no | | Exposes no focused element at all and takes a ⌘V perfectly well. The paste route's old precondition — "can Accessibility see a focused element" — therefore refused to try in exactly the applications the route exists to serve, and every dictation into one fell through to the clipboard to be pasted by hand ([input-paste-eligibility.md](input-paste-eligibility.md)) |
| Slack | — | | | | | | | no | no | | The reading is of the window, not of a focused field, so `Published` stays blank. Neither a window title nor a selection ([context-accessibility.md](context-accessibility.md)); `AXTextInputMarkedRange` absent from the binary ([predict-ime.md](predict-ime.md)) |
| Visual Studio Code | | | | | | | | | no | | Marked range absent from the binary. Nothing else measured ([predict-ime.md](predict-ime.md)) |
| WhatsApp | chat composer | | | | | | | no | no | | Messages are published as static texts with an empty value and the text in the description, date headings are nested, and the recipient appears only as a group label — so the collector reads the description as a text fallback. Every bubble's label glues its timestamp together, "3Septemberat6:41 PM", which the model then imitates, so stamps are stripped from every label read ([predict-reliability.md](predict-reliability.md)). The marked range is not published ([predict-ime.md](predict-ime.md)) |

## Native AppKit

| App | Field | Published | AX write | Paste | Confirmed | Full route | Caret | Value | Marked text | Completion | Notes |
|---|---|---|---|---|---|---|---|---|---|---|---|
| Notes | multi-line | | | | | | | | yes | | An `NSTextView`: publishes `AXTextInputMarkedRange`, and it tracks a composition faithfully — `loc:6 len:4` while composing `にほんご`, `len:2` when the composition is shortened, back to length zero on commit or cancel ([predict-ime.md](predict-ime.md)) |
| Mail | multi-line | | | | | | | | yes | | The same `NSTextView` reading ([predict-ime.md](predict-ime.md)) |
| TextEdit | multi-line | yes | | | | once | right | | yes | correct | `Published` and `Caret` follow from the harness drawing an inline ghost here, which needs both. One of the four applications the idle-gated live end-to-end harness runs in, so the drawn ghost, the accepted key and the read-back are exercised here every cycle ([predict-reliability.md](predict-reliability.md)) |
| Messages | chat composer | | | | | | | | no | | A single-line `NSTextField` does not publish the marked range ([predict-ime.md](predict-ime.md)). The person's recent lines in the field were drawn from every conversation at once, so a greeting typed to one contact led the list in a chat with another; lines from this conversation now come first ([predict-reliability.md](predict-reliability.md)) |
| Finder | search field | yes | | | | once | right | | no | correct | `Published` and `Caret` as for TextEdit above. The second of the four live-harness applications ([predict-reliability.md](predict-reliability.md)) |
| System Settings | search field | | | | | | | | no | | ([predict-ime.md](predict-ime.md)) |
| — | any single-line `NSTextField` | | | | | | | | no | | The marked range reaches AppKit multi-line text views and nothing else, which means it misses single-line fields — where a completion is worth most ([predict-ime.md](predict-ime.md)) |
| — | any secure field | | see the caveat above | | | | | no | | A password or PIN field takes the words like any other field and nothing else does: the outcome is marked `intoSecureField` and the words reach no store at all — no history row, not even a length, no clip, no dictionary lesson, and the floating button neither draws nor reads them. A paste writes `org.nspasteboard.ConcealedType` beside the text ([insertion.md](insertion.md)) |

## Terminals

| App | Field | Published | AX write | Paste | Confirmed | Full route | Caret | Value | Marked text | Completion | Notes |
|---|---|---|---|---|---|---|---|---|---|---|---|
| Terminal | shell | yes | refused | | | once | right | yes | no | correct | Window title and selection both answered ([context-accessibility.md](context-accessibility.md)). The Accessibility route widened the selection over the typed `s`, Terminal refused the text, and the failed strategy left the selection behind; the keystroke route then read the wrong character before the caret and refused too. A field that takes the selection and refuses the text now has its caret put back before the next route runs — on the completion path only, since that is the one that widens a selection at all; a dictation writes at the caret and has nothing to restore ([predict-reliability.md](predict-reliability.md)). The marked range is not published even on Terminal's own `AXTextArea` ([predict-ime.md](predict-ime.md)). The third live-harness application |

An address bar — the fourth live-harness surface — is measured under Browsers above.

## Cross-platform toolkits

| App | Field | Published | AX write | Paste | Confirmed | Full route | Caret | Value | Marked text | Completion | Notes |
|---|---|---|---|---|---|---|---|---|---|---|---|
| DBeaver (Java/SWT) | rich editor | no | | | | | none | no | | nothing | The focused element is an `SWTComposite` or an outline and most reads fail outright; from the background the application reports no focused element at all. **No fix is possible on the reading side** — the way through is a second source for the line, from the keystrokes the event tap already sees, and a place to draw that needs no caret rectangle. Both are design work ([predict-reliability.md](predict-reliability.md)) |

## Office, spreadsheets, remote desktops and VMs, games

**Nothing measured.** No document in this repository records a reading from a spreadsheet
cell, a remote desktop, a VM window or a game, so there are no rows to write and none are
invented here. #626 covers office and a spreadsheet cell, #627 a remote desktop or VM
window, and #619 is the code-level gap those would confirm.

## How to add a row

One application, one field, twenty minutes. You need Accessibility granted to the
**terminal** you run from, not to the binary: Accessibility is attributed to the
responsible process, so an unsigned `swift build` product inherits the terminal's grant
and needs no password of its own ([predict-ime.md](predict-ime.md), under "An aside that
unblocks the pending sweeps").

1. Open the application's About window and write down its version and the macOS version.
   The rows above carry no versions, because the documents they come from did not record
   any — which is exactly why none of them can be re-confirmed rather than re-measured.
   Do not repeat that.
2. `swift run uttrflow-dev probe surface --seconds 60`, then click into the field you are
   measuring. Fills `Published`, `Caret`, `Value`.
3. `swift run uttrflow-dev insert --via accessibility "one two three"` and watch the
   screen. Read the column off what it prints — "the field refused the text (…)" is
   *refused*, "accepted the text and did not change" is *reports success, changes
   nothing*, and `Inserted via accessibility` over an unchanged screen is the
   unanswered-value case in the caveat above, which is worth saying so in Notes.
4. `swift run uttrflow-dev insert --via paste "four five six"`. Fills `Paste` and
   `Confirmed`; read the caveat above before recording a timing from it.
5. `swift run uttrflow-dev insert "seven eight nine"`, no `--via`, for `Full route`.
   *Twice* means two strategies both landed, which is a defect, not a success.
6. `swift run uttrflow-dev probe ime` for `Marked text`.
7. Accept a suggestion by hand for `Completion`.

Then add the row under the right class heading, with the source in the Notes cell: a
document link if you also wrote the reasoning up on that page, or the issue number of the
run if you did not. **Leave every cell you did not measure blank.** A plausible cell is
worse than an empty one here, because the empty one tells the next person what to go and
measure and the plausible one tells them not to bother.

Use the field's own vocabulary in `Field` rather than the application's marketing name for
it, so that a row about a chat composer sorts beside every other chat composer.

## What is still missing, and who has it

The `Published`, `Caret` and `Value` columns are thin above because the sweep that fills
them across many applications at once is #101, and the run is in flight. When it lands,
[predict-probe.md](predict-probe.md) holds the readings and this page should cite them per
row rather than repeat them.

Per-class testing, one application each: #622 a browser, #623 an application on a bundled
browser engine, #624 a terminal and a TUI, #625 an IDE, #626 native mail, messages, notes
or office including a spreadsheet cell and a password field, #627 a remote desktop or VM
window, #628 right-to-left, Devanagari and input-method typing.

Code-level gaps found while drafting the columns, each naming the cell that would confirm
it: #600 the paste key code on other keyboard layouts, #601 an Accessibility write that
lands late, #603 the word under the caret read instead of the field, #605
`AXManualAccessibility`, #606 typed completions and key code 0, #608 secure keyboard entry
and the shortcut, #610 dictating into a password field, #612 line breaks into a terminal,
#614 the two terminal tables, #616 right-to-left ghost placement, #618 carets in the Dock
and menu bar bands, #619 remote desktop and VM windows, #621 a silent panel paste.

## What the pages this draws on keep

Each of the seven goes on owning its own subject and feeds named columns here; none of
them keeps a per-application table of its own any more except where the table *is* the
subject.

| Page | Feeds |
|---|---|
| [insertion.md](insertion.md) | `AX write`, `Paste`, `Confirmed`, `Full route`, and the secure-field row |
| [input-paste-eligibility.md](input-paste-eligibility.md) | `Paste` — when the route volunteers at all |
| [context-accessibility.md](context-accessibility.md) | `Value` — the window title and the selection, answered separately |
| [predict-ime.md](predict-ime.md) | `Marked text` |
| [predict-reliability.md](predict-reliability.md) | `Caret`, `Value`, `Completion`, and most of the Notes |
| [predict-probe.md](predict-probe.md) | `Published`, `Caret`, `Value`, once #101's sweep lands |
| [input-synthetic-keystrokes.md](input-synthetic-keystrokes.md) | `Completion` and the undo note — what a posted event contains, which is the same everywhere and so has no per-application rows: events are chunked at 16 UTF-16 units on a character boundary, flags are cleared explicitly, and a replacement costs one Delete per character, which is why the keystroke route shows the target's undo several edits where the Accessibility route shows one |
