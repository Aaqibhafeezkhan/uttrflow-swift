# Onboarding: the rules the flow is built on

`OnboardingFlow` in `Sources/UttrflowUX` drives first-run onboarding without a screen. The
window above it only draws. These are the decisions that shape it and that a reader
changing it needs to keep.

## Five pages, each answered before it is left

Sign in, Microphone, Accessibility, Speech model, Ready. What Uttrflow is for is said on
the sign-in page itself; there is no separate welcome.

- Nothing is remembered about the system. A permission is read from its gate at the
  moment it matters, never carried forward from the click that asked for it.
- Every page but the last is mandatory. Sign-in has no way past it but an account; a
  permission page offers Continue only once macOS reports it granted; the download page
  offers Continue only once the model is on disk, and its Cancel stops the download and
  offers Try again rather than moving on. `OnboardingFlow` refuses a stray `.advance` on
  an unanswered page, so the rule holds even if a page offered one by mistake.
- The one exception is a device policy (`.restricted`): granting is not on offer at all, so
  Continue is the only answer left, and the last page says what it cost.
- A granted permission and a finished download stay on screen to say so, and the user
  presses Continue; nothing moves the page on by itself.
- A page argues only with somebody who has refused it. `AXIsProcessTrusted` cannot say
  "not asked yet", so the Accessibility page opens at `.denied` with nobody having refused
  anything; `PermissionKind.reportsNotDetermined` is what tells the two apart, and it is
  why that page's first answer is still the ask rather than a trip to System Settings.

## Offline

The sign-in page is the only page that needs a server, which is why `NetworkReachability`
is asked before the provider buttons are drawn live. Whether somebody is *already* signed
in is never asked of a server: `EntitlementGate` answers it from a cached, signed
entitlement, so every launch after the first works with Wi-Fi off. An entitlement that has
aged out still counts as signed in; it degrades, it does not lock.

## Sign-in is one awaited call

The whole exchange — start, open the browser, wait for the backend to say the browser half
is done, read the profile — is one awaited sequence rather than two halves joined by a URL
the operating system delivers. No token ever travels through the browser: the app collects
the session over its own connection, using a claim token the browser never saw.

What that buys: the app is not reachable through a URL scheme any other program on the Mac
can invoke, there is no callback that can arrive after the user has walked away, and the
sign-in either completes in the flow or does not happen at all. Cancelling the task is what
makes the Cancel button real; the browser tab stays open and the backend forgets the
attempt within ten minutes.

A Mac that cannot bind a loopback port (SSH, a container, security software) is given a
code to type instead, and the page says so.

The provider's page opens in the user's own browser, never a web view: a password is typed
there, and the only window in which that is safe is one whose address bar the user can see
and whose password manager they already trust.

## No way past sign-in

Sign-in is mandatory and nothing else in the app opens without a session; see
`Docs/entitlements.md`. There is no way to work without an account. A Mac upgraded from a
build that offered one has its old record removed at launch (`RetiredLocalAccount`) and
opens on this page, even though its setup is finished.

Offline, the sign-in page offers only Try again.

`OnboardingFlow.onSignIn` fires as soon as the profile is kept, so the rest of the app is
switched on before the remaining setup pages, whose last one asks for a first dictation.

## The first try

The last page asks the user to hold their shortcut and talk. `OnboardingWindowController`
maps each `DictationState` to an `OnboardingTrial`: recording is listening, and the words
of an insertion — or of a failed one, since Uttrflow does not type into its own window —
fill the page's field. `OnboardingFlow.tried(_:)` shows them for a moment and then closes
onboarding, which opens the dashboard. Empty words go back to waiting. "Skip to dashboard"
closes onboarding at any time.

## Finishing writes no preference

`finish` does not turn `opensAtLogin` on. `Settings` ships with it `true`, and a stored
`false` can only have been written by the switch on the Settings screen, so every write
here would be either a no-op or an override of the user's choice.

## Generations

Both the download and the sign-in outlive the click that started them. Each is guarded by
a generation counter bumped when the user walks away, so a late result cannot redraw a page
that is no longer on screen. The one exception is a sign-in that completes after Cancel:
the user is signed in, and the page moves on regardless.

## Closing the window during the download

Closing the onboarding window, with its red button or otherwise, does not stop the speech
model's download: it keeps running and stays visible. The app owns the one download
(`SharedModelInstall`), and every onboarding window joins it rather than starting another, so
reopening setup mid-download shows the same download instead of writing a second copy into
staging. While it runs, the menu bar and the floating button show "Setting up…" with the
percentage; when it lands the model is loaded without a relaunch, and when it fails they go
back to saying setup has not finished. Only the page's Cancel button stops it.

The app forgets the onboarding window however it closes, so an update waiting for a quiet
moment is not held back by a window that is no longer on screen.
