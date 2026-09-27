# Onboarding window: sizes and the provider marks

## Window and card

860 × 560, drawn dark whatever the Mac is set to (`window.appearance = .darkAqua`). The
aurora behind everything takes its colours from the page's `OnboardingMood`; it turns once
every forty seconds and holds still under Reduce Motion, Low Power Mode or thermal pressure
(`MotionBudget.demonstrationMoves`). The problem moods (warning, failure, offline) are drawn
dimmer, so bad news is never the brightest thing on screen. No animation pulses: the
waveform, the sign-in arc and the typing field move, and all of them are gated by the same
budget.

The logo top-left is `UttrflowMarkView` on a dark tile beside the wordmark in Outfit; there
is no second logo asset. The card is 390 points wide, 40 from the right edge: a picture on
top, then the heading, round buttons, a hint and one dot per step. Every colour is in
`BrandPalette.Onboarding`.

## The Google mark

Apple's mark ships with the system. Google's is somebody else's trademark, so
`Scripts/fetch-provider-marks.sh` fetches it from the artwork Google publishes for exactly this
button and `.gitignore` keeps it out of the repository. Shipping it inside an app that
implements Google Sign-In is what it is published for; redistributing it in public source is a
different act.

It is never recoloured, rotated or redrawn. That is why it is a picture rather than a `Path`
somebody would later be tempted to tint; redrawing it as a vector is the one thing the terms do
not permit.

`image(forResource:)` returning `nil` is a supported state. A checkout that has not run the
script draws a plain person symbol in the round button with the provider's name under it,
which is also what the GitHub button would draw: its mark is not fetched either.

## Providers

Only the providers in `SignInProvider.offered` are drawn. The backend knows how to speak to
Google and GitHub, but a deployment offers only those it has credentials for, and the
production backend offers Google alone today, so the sign-in page draws one round button.
Adding `.gitHub` to `offered` once the backend has GitHub credentials puts it beside Google.
