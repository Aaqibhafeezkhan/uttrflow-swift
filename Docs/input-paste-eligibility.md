# When the paste strategy volunteers

`PasteboardTextInsertionEngine.canInsert()` declines for one case only: Uttrflow itself
being the frontmost application. Everything else is worth attempting.

Per-application results live in [compatibility.md](compatibility.md), whose `Paste` column this
page feeds — specifically whether the route volunteers at all.

## Asking Accessibility first refused the applications pasting exists for

The precondition used to be "can the Accessibility API see a focused element", which
sounds prudent and is wrong twice over.

Editors built on Electron — Cursor is the one this was reported from — expose no focused
element at all and accept a ⌘V perfectly well. So the check refused to try in exactly the
applications the paste strategy exists to serve, and every dictation into one of them fell
through to the clipboard for the user to paste by hand. The same shape appears in web
views and anything that draws its own text: a focused element that will not report its
selection, which the Accessibility strategy above cannot write into either.

`Docs/insertion.md` has the other half of the same trap — the Electron field that accepts
an Accessibility write, answers `.success`, and changes nothing.

## Trying and failing costs nothing

The reason the check was ever narrow is gone. Pasting no longer restores the borrowed
clipboard, so the worst an attempt can do is leave the words on the clipboard — which is
precisely what the strategy below it would do. Declining, by contrast, costs the user
their insertion. So the engine volunteers and the coordinator finds out by trying.

## Never into Uttrflow itself

The one refusal. Uttrflow's own windows are where the user is choosing a shortcut or
reading their clip history, and a ⌘V posted while one of them is in front lands in the
app's own text rather than in the document the dictation was for.

## Checked twice, because the answer can go stale between the two

`canInsert()` and `insert()` are two separate `await`s on the same actor, so real time
passes between them — long enough for the user to switch to Uttrflow while a dictation
is still being recognised or cleaned up. A `canInsert()` answered for another app must
not be trusted by the time the write actually happens.

So `insert()` asks `isSelfFrontmost()` again, immediately before it writes the clipboard
and posts ⌘V — not only once, up front. If Uttrflow has become frontmost since
`canInsert()` ran, `insert()` throws `.noFocusedTextField` without touching the clipboard,
and `TextInsertionCoordinator`'s fallback chain takes over from there, same as any other
strategy declining.

The same re-check sits at the write in `TypedTextInsertionEngine`, for both `insert()` and
the completion route's `write(_:replacing:)`: every strategy that posts into whatever is
focused asks again immediately before it backspaces or types, not only the paste route.
