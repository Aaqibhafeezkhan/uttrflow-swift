# Watching the heap over hours

`Scripts/soak.sh` exists for one question, and it is the question #140 could not answer by
reading code: **is something accumulating?**

Both crashes in that issue are a deinit cascade deep enough to exhaust a thread stack, entered
from `DictationController.stop()`. A cascade needs a chain, and a chain long enough to blow a
stack has to be built over time. Neither crash reproduced on a fresh session — the two processes
that died had been running for two hours and nearly thirteen. So the thing to look at is not a
gesture but a duration.

```bash
make soak                                  # 6 samples, 10 minutes apart
./Scripts/soak.sh --every 60 --times 30    # half an hour, finer
./Scripts/soak.sh --pid 1234
```

Leave the app running and **used** while it samples — dictations, the clipboard, and suggestions
switched on, since the longer-lived crash had them enabled. A soak against an idle app measures
an idle app.

## What it reports

Each sample is `heap <pid>`, reduced to a count per class and kept in `dist/`. At the end it
prints the classes that grew most between the first sample and the last, with the footprint and
the live node count beside them.

**A count that only ever rises is the answer.** One class climbing while everything else moves
about is the chain; that class is one end of it, and whatever frees the head of it is the other.

A chain need not be a class `heap` can name. The one behind #140, found in #340, was closure
contexts: `SystemKeyboard` kept its sink as a bare closure in a `Mutex`, and reading a closure out
through `withLock`'s `inout` re-wraps it in reabstraction thunks and writes the wrapper back, so
every keystroke added a layer. Delivering a stroke called through every layer and stopping the
keyboard freed them recursively. The sink is now a struct holding the closure, and
`SystemKeyboardDeliveryTests` measures the stack depth of both paths, which a soak cannot.

## #1468: the same stack on a build that has the fix

A report from 2026.9.14 (9) shows the #140 shape again: 3,347 levels of
`_swift_release_dealloc` → `doDecrementSlow` → one Uttrflow frame, under
`SystemKeyboard.stop() + 96` on the quit path. What was checked against that build, and ruled out:

- **The shipped binary cannot start a chain from `stop()`.** Disassembled from the published
  disk image, `SystemKeyboard.stop()` is 104 bytes and releases two things: the running tap at
  `+56` and the sink at `+84`. Neither owns anything that owns more of its own kind. `+96` is
  the epilogue before a tail call, not a return address, so the report's innermost frame does
  not name code in that binary and its frame names cannot be taken at face value.
- **Nothing on the keystroke path allocates.** In that binary and in a Release build of
  `main`, the tap callback and the monitor's stroke closure make no `swift_allocObject` call:
  the sink is copied out of its lock, called and released, and never written back. A chain
  built per keystroke needs an allocation per keystroke. The only allocations on this path are
  per start (the tap, its thread, the sink) and per press (the reconciliation timer), and each
  replaces the one before rather than holding it.
- **A finished `Task` releases what it captured**, measured directly, so the task chains
  elsewhere in the app (`let previous = task; task = Task { await previous?.value }`) unwind as
  they complete rather than growing.

`SystemKeyboardTeardownDepthTests` is the guard. It drives 120,000 real `CGEvent`s through the
real tap callback, the real `Delivery` and the real `ActivationMonitor`, press, release and
typing alike, then calls the quit path's `stop()`, all on a 64 KiB thread. It passes on `main`.
With the sink put back as a bare closure in the `Mutex` (the #340 shape) the test process dies
with `SIGBUS`, the field crash, so a chain of that kind cannot come back unnoticed. What the
report actually freed is still unnamed; the dSYM that release builds now keep is what names it.

## What it cannot tell you

It counts objects; it does not say who retains them. Once a class is named, the next step is
`MallocStackLogging=1` and `malloc_history <pid> -allBySize`, or Instruments' Allocations
template with a generation marked before and after — those give the allocation backtrace, which
is what turns "this is growing" into "this is what holds it".

It also cannot prove a fix. A run that stays flat for an hour is evidence, not a guarantee, and
the honest report of one is the numbers rather than a verdict.

## Why it is not part of any gate

It takes hours, it needs a real windowing session, and it measures a process nobody is driving
unless somebody is driving it. `make verify` stays fast and hermetic; this is a thing you run
deliberately, at a machine, when you want to know.
