# Settings: why decoding is forgiving, field by field

`Settings` is one JSON blob under one `UserDefaults` key, so a save is whole and needs no
migration step. What that costs is decoding, and `Settings.init(from:)` in
`Sources/UttrflowSettings/SettingsStore.swift` pays it deliberately.

## One value rather than a scattering of keys

A screen can be handed the whole configuration, compare it, and write it back in a single
step, so a half-applied change is not representable. Nothing in it leaves the Mac.

## Synthesised decoding is all-or-nothing, and that is the wrong trade

One field a newer build added, or one a hand-edited preferences file mangled, and the user
loses every other choice they ever made. Settings are worth less than the confidence that
they survive, so a field that cannot be read is treated as the field the user never
changed.

The same forgiveness runs the other way. A key this build has no case for —
`recordingRetentionDays`, which set the retention of audio the app never wrote to disk — is
a key that keyed decoding is simply never asked for, so a blob an older build left behind
still yields every choice that does still mean something. A dropped key is also a door left
open: a hostile value stored under one must not come back in through it.

## Three states, and `decodeIfPresent` only tells apart two

`clipboardHotkey` is optional because "no clipboard shortcut" is a position a user can hold
— the panel is still reachable from the menu bar. So the field arrives in three ways that
mean three different things:

| On disk               | Meaning                    | Result           |
|-----------------------|----------------------------|------------------|
| key absent            | never chosen               | the default      |
| `null`                | chosen to have none        | `nil`, honoured  |
| present, unreadable   | no preference this build can act on | the default |

`decodeIfPresent` answers the same `nil` for the first two, so a shortcut the user had
switched off would come back by itself on the next launch. `optionalValue(forKey:default:)`
checks `contains(key)` first, then decodes.

### The footgun inside it

`try? decodeIfPresent(T.self, forKey: key)` flattens nested optionals. "It threw" and "it
decoded a `null`" collapse into the one `nil` the method exists to tell apart — silently,
with the right type and no warning. The error is caught by hand for that reason.

## Values that decode cleanly and are still unusable

Decoding cleanly is not the same as being usable.

- **Retention.** Zero or less would wipe the user's history the instant the app launched,
  so a value that says so is treated as a corrupt one and becomes that field's default:
  `Settings.defaultTranscriptRetentionDays` (keep until deleted) for transcripts, and
  `Settings.defaultRetentionDays` (7) for unkept clips. Only a missing or unusable value
  takes the default; a period the user saved, 7 included, is kept as it is.
- **The dictation shortcut.** `{"keyCode": 49, "modifiers": []}` is a perfectly good
  `HotkeyBinding` and a shortcut that never fires. There is no screen for choosing another,
  so the only way back would be deleting the preferences file from a terminal. An
  undeliverable shortcut falls back to Option+Space, and so does a file that names no
  dictation shortcut, since only an earlier build writes one. See `Docs/shortcuts.md`.
- **The clipboard shortcut.** It has no such obligation, so an unusable one resolves to
  nothing rather than to a key the user never chose and would meet by surprise in another
  app.
- **A modifier held on its own**, in either shape of file and for any action. Earlier builds
  let the user choose it, so it was a decision rather than corruption, and dropping it would
  leave the action with no shortcut and no explanation. It returns to the action's default
  instead, the clipboard included, unless another action already holds those keys. The
  action is added to `shortcutsReturnedToDefault`, which is stored like any other field. The
  note therefore outlasts the save that removed the binding, and it stays until the user
  sets that shortcut again. See `Docs/core-hotkeys.md`.

## The clipboard-shortcut collision

Carbon accepts both registrations of a single combination and then fires both, so a
collision left in place starts a dictation *and* opens the panel on one keypress. The
dictation shortcut keeps the key, because it is the one with no second way in; the
clipboard shortcut resolves to nothing and the shortcuts screen says so.

That is also why the dictation shortcut is resolved before the initialiser call rather than
inside it: the clipboard shortcut is only valid relative to it, and the argument order of an
initialiser is not a place to hide a dependency between two of its arguments.
