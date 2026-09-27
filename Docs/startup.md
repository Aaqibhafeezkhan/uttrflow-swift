# Launching, and the minute before the app can dictate

## What users saw

Open Uttrflow, press the shortcut straight away, speak, let go — and nothing happens for
a long time, or nothing happens at all. The menu bar said **Ready** the whole time.

## Why

Two separate mistakes, both of which made the app claim to be working before it was.

### The menu bar answered a different question

`MenuBarState.speechModel` was computed as:

```swift
speechModel: modelStore.isInstalled(.default) ? .ready : .notInstalled
```

`isInstalled` asks whether the model's *files are on disk*. Whether the model has been
**loaded into memory and can transcribe** is a different question, and it is the one the
user is asking. Between launch and the end of the load, the answer to the first is yes
and to the second is no.

That gap is not small. Measured on this Mac with the shipping model
(`openai_whisper-large-v3-v20240930_turbo_632MB`):

| | time to load |
|---|---|
| first load after boot, cold page cache | **154 s** |
| every load after that, warm | 2.1 s |

**Where those seconds go is not yet known**, and the load now says so itself. WhisperKit measures
the parts of its own load — prewarm, encoder and decoder specialisation, encoder and decoder load,
the tokenizer — and nothing was reading them; `WhisperKitBackend` logs them beside its own total
under the `speech` category, so a reboot and one dictation produce the breakdown:

```
log show --last 10m --predicate 'subsystem == "com.uttrflow.Uttrflow" && category == "speech"'
```

Read it cold, after a reboot and before anything else has touched the model folder — a warm
reading is the 2.1 s row and says nothing about the problem. Whether the answer is CoreML
specialising the model or paging 632 MB of weights in decides what is worth doing about it, and
the two candidates (a compiled artefact produced at install time; a smaller first-run model
upgraded in the background) trade against each other differently depending on which it is.

Two and a half minutes of a menu bar saying Ready is the whole bug report. The
presenter was always able to say otherwise — `SpeechModelReadiness` has a
`downloading` case, `statusLine` renders it, and `canStartDictation` refuses while it is
not `ready`, with a comment saying *"a 'Ready' that cannot dictate is worse than saying
nothing at all"*. It was simply never told.

There is now a `loading` case, and the app reports it from the pipeline's own
`isReady` rather than from the file system. The clipboard panel's dictation button asked
the same wrong question and now asks the same right one.

### `prepare()` dropped itself when the user was quick

```swift
public func prepare() async {
    guard !isBusy else { return }      // ← silently does nothing, and never retries
```

`applicationDidFinishLaunching` starts watching for the shortcut *before* it asks the
pipeline to prepare. Press the shortcut in that window and the pipeline is already
recording, so `prepare()` returned immediately, having done nothing, and nothing ever
called it again. The model was then loaded inside the first transcription, by
`BackedSpeechEngine.transcribe`'s own fallback — during which the user is holding a key
and looking at a menu bar that says Ready.

The guard was there to protect the state machine, not the loading: `prepare` transitions
to `failed` on error, and doing that over a live recording would be wrong. So the guard
now covers only the transition. The load itself always runs, and can run *while* the
user speaks — which is strictly better, because it warms the model during the one moment
the app knows a transcription is coming.

## What a person is told during the load

The menu bar is only seen when somebody opens it, so the load is also said wherever a person
would try to dictate. Every surface reads the same `SpeechModelReadiness` the menu bar does,
turned into `SpeechModelLoad` (`Sources/UttrflowCore/Models/SpeechModelLoad.swift`), which is
the one home for the words and for when the minutes are said.

| Where | While loading | If the load fails |
|---|---|---|
| Home page | A card: **Loading the speech model…** with a spinner, and the ring's status reads *Loading speech model*. | **The speech model didn’t load**, with **Download**. |
| Floating button | A wide pill with an hourglass: **Loading speech model…** | **Speech model didn’t load**, with **Download**. |
| Shortcut or button pressed | **Speech model still loading…** through the same notice every dictation failure uses, informational, and the microphone never opens. | Dictation starts, and the recogniser tries the load again on demand. |
| Clipboard panel | The microphone is off: *Speech model still loading*. | Off, as for a model that is not ready. |
| Menu bar | *Getting ready…*, then the estimate below | *Speech model didn't load* |

**A model that is not on disk at all** is `SpeechModelLoad.missing`, read from the same
`.notInstalled` readiness the menu bar reads. Home shows **The speech model isn’t downloaded**
with **Download**, its ring out and its status *Speech model not downloaded*; the Dictation page
says the same in place of its invitation to talk; the menu bar reads *Speech model not
downloaded*. The floating button stays the resting grip, since setup is what fetches a missing
model. The Dictation page names a load or a failure the same way when it has nothing else to show.

Home's resting status is *Ready* and, while something blocks dictation, *Not ready* or the
model's own status. It never says *Listening*, which on the menu bar and the floating button
means the microphone is open.

**The minutes are said only once a load has run for five seconds** (`SpeechModelLoad.estimateAfter`).
A warm load is over in about two, so it never claims minutes, and until then home, the menu bar
and the floating button say *Getting ready…* over a sliding bar or a spinner. A load still going at
five seconds is almost certainly the cold case, and from then every surface shows an estimate.

### The estimate

Nothing reports how far a load has got; the app knows only how long it has run. So the bar is a
guess paced to a typical cold load, from `SpeechModelLoadEstimate`
(`Sources/UttrflowCore/Models/SpeechModelLoadEstimate.swift`):

- **`SpeechModelLoadEstimate.typicalColdLoad` is the one number to tune.** It is 150 seconds,
  from the 154-second cold load measured above. A slower Mac overruns it and holds at 90 %
  for longer; a faster one jumps to done early. Change the constant, not the curve.
- **The bar eases out** from 0 to 90 % (`ceiling`) over that time — `0.9 × (1 − (1 − t)²)` with
  `t` the share of the typical load gone — so it moves quickly at first, slows as it nears the
  ceiling, and never goes backwards. It then **holds at 90 %** until the model is really ready,
  and the surface drops the bar for the ready state.
- **The time left is said in four phrases**, from the typical load minus the elapsed time: more
  than 90 s left is *about 2 min left*, more than 45 s *about 1 min left*, anything less *less
  than a minute left*, and once holding *almost ready*. The floating button uses the short form
  (*~2 min*, *~1 min*, *<1 min*), and VoiceOver hears the minutes written out.

| Where | Past five seconds |
|---|---|
| Home hero | **Getting ready · about 1 min left**, under it *Only after a restart. Everything else already works.*, and the bar filled to the estimate. Holding: **Almost ready…** |
| Floating button | A ring filled to the estimate, **Getting ready**, and *~1 min*. Holding: **Almost ready**. |
| Menu bar popover | The same heading as home over a bar filled to the estimate. |
| A dictation refused during the load | **Speech model still loading…**, and under it the same time left: *About 1 min left*. Holding: *Almost ready*. |

The floating button and the menu bar redraw once a second while the load runs, from
`AppDelegate`'s ticker, which starts at `estimateAfter` and ends with the load; nothing ticks once
the model is ready. The home hero is not redrawn by that ticker, because redrawing the main window
rebuilds every page from the whole history. Its status block (`HomeModelStatusView`) carries the
load's start and runs its own `TimelineView`, so only that block redraws: once a second while its
window is in use, and every 15 seconds while it is not. The bars ease between ticks, and under
Reduce Motion they step instead.

The refusal lives in `DictationPipeline.startRecording`, which declines while its own `prepare()`
is running. A pipeline nobody prepared still records and loads on demand, as before. When the
load ends the refusal's notice is cleared, and every surface goes back to what it drew before.
**Download** on a failed load deletes the model that will not load and opens setup to fetch it
again; closing setup loads whatever it installed. A model counts as installed only when every file
a load reads is there, so a load that still fails is damage the store cannot see from outside, and
a fresh copy is the repair. The notice a failed load raises in the pipeline keeps **Try Again**,
which loads again rather than starting a dictation.

A load that never returns is a failed load too. `prepare()` waits at most
`StageTimeout.speechModelLoad`, 300 seconds, about twice the 154-second cold load measured above.
It then fails with `modelLoadFailed`, and the surfaces show the same recovery as any failed load:
**Try Again** the first time, **Download** after a second failure. It stops waiting instead of
cancelling and waiting for the cancel, because a blocked recogniser load does not answer a cancel.
The abandoned load finishes whenever it can, and a load that finishes late is ignored.

## What is still true

A cold load is still 154 seconds. Nothing here makes it faster; it makes the app honest
about it. Making it faster is a separate question — the load is CoreML compiling and
paging in a 632 MB model, and the lever is the model, not this code.
