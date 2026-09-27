# Settings controls

`SettingsControlView` draws whatever a settings row asked for. It is one `switch` over a closed
set, so a control the presenter can ask for and the page cannot draw does not compile. Every case
reports the change the presenter already attached to the choice; none of them works out what a
choice ought to mean.

## Labels and VoiceOver

Every control here is drawn with `labelsHidden()`, because the row already writes the label beside
it. The label still has to be passed in and reattached with `accessibilityLabel`: while it was
`""` there was nothing for SwiftUI to hand to VoiceOver either, and focusing any switch in Settings
announced "checkbox, checked" and named nothing. The row's own words are the right label.

A language chip's × says which language it stops listening for, since a bare × names nothing,
and the last language has no × at all rather than one that is refused after it is pressed.

## Destructive versus ordinary buttons

`removal` routes through `model.request`, which asks for confirmation where the level needs it,
and is red when it resets everything.
`action` is neither red nor confirmed. The two cases exist precisely to keep those treatments
attached to one of them and not the other, and neither is ever
`.keyboardShortcut(.defaultAction)`: nothing on this screen removes anything because Return was
pressed.

## Recording a shortcut

Keystrokes are taken through a local `NSEvent` monitor rather than SwiftUI's focus machinery,
because the combinations worth recording — ⌘Q, ⌥Space — are the ones the menus and the responder
chain would otherwise eat before any view saw them. The monitor is installed only while recording.
Recording is also tied to the Settings page being the key surface: leaving the page, moving to
another window, or leaving the app cancels the attempt and restores the live shortcut monitor.

### `.flagsChanged` as well as `.keyDown`

A modifier pressed on its own sends only `.flagsChanged`. Without listening for it, somebody trying
to bind ⌘ or Fn alone — the obvious thing to try on a dictation app, and what several of them use —
pressed their key and the field said nothing at all: no shortcut, no refusal, just "Press the new
shortcut" for ever. Silence reads as a broken field rather than as a rule. Such a binding is
genuinely undeliverable, so it is still refused; the point is that it is refused out loud.

A modifier-only press — ⌃⌥, or ⌘ on its own — arrives with the flags set and a modifier's own key
code, and is recorded as the hold it is. Falling through to the ordinary refusal is what once
answered ⌃⌥ with "Try a letter, a number or Space".

`.flagsChanged` also fires on the release, where the flags have gone empty. Only the press is an
attempt at a shortcut; reporting the release as one would answer a single tap with two different
complaints.

### Fn

Fn is a shortcut in its own right — held, not combined — so it is recorded rather than refused. It
carries none of the four modifiers this app names, so it has to be recognised by `.function` and
its own key code before the empty-modifier check would throw the press away as a release.

### What is swallowed and what is passed on

A key press is swallowed, so nothing pressed at this field reaches the rest of the app: recording
⌘Q records or refuses that candidate, but it does not quit Uttrflow. A modifier change is passed on:
swallowing one would leave the rest of the app believing a key is still held after the user let go.

Only four modifiers are recognised — command, option, control, shift. Caps Lock, Fn and the
numeric-keypad bit are noise the window server sets on its own.

### The field owns the recording only while it is the key interaction surface

The main window losing the keyboard cancels the recording, through
`MainWindowController.onSettingsLostFocus`, because a keystroke meant for the next application
must not be saved as Uttrflow's shortcut. The session tap stops, the key-down swallow goes with it,
and another ⌘Q reaches the foreground app normally. Leaving the Settings page for another page does
the same, and so does a search that hides the row that is listening.
