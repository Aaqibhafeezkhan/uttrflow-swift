# Dictating with no network

Uttrflow's claim is that hold-key → capture → transcribe → tidy → insert touches the
network zero times once the speech model is on disk. This is the evidence for that
claim and the things it does not prove.

Re-run the static half with `./Scripts/offline_audit.sh`. It exits non-zero if a network
call site appears anywhere under `Sources/` outside the files that are allowed one, or if
a linked object can reach the network and was not expected to. *What the audit checks*
below lists every check and what each one cannot see.

**Nobody's Wi-Fi was switched off to produce any of this.** The network was denied per
process with `sandbox-exec`, which needs no system setting and affects nothing outside
the process it launches.

## Method

Three kinds of evidence, because no one of them is enough on its own.

| | What it can show | What it cannot |
|---|---|---|
| Source audit | Every call site somebody wrote | Nothing about dependencies compiled from elsewhere, or about what actually runs |
| Binary audit | Which linked module can open a connection at all | When, or whether, it does |
| Sandboxed run | What the code really does, once | Only the paths that run actually get exercised |

The sandbox profile is three lines:

```scheme
(version 1)
(allow default)
(deny network* (with send-signal SIGKILL))
```

`SIGKILL` rather than a plain deny is what makes a *successful* run mean something. A
denied connection returns an error the program might swallow and carry on from; a
killed process cannot. So a run that exits 0 under this profile has provably not made a
single network syscall. Verified against a control first:

```
$ sandbox-exec -f kill-on-net.sb /usr/bin/curl -s -m 8 -o /dev/null https://1.1.1.1
curl EXIT=137        # 128 + SIGKILL
```

## Every network call site

### Uttrflow's own sources: nine files, and none of them on the dictation path

The full pattern — Foundation's stack, Network.framework in both spellings, CFNetwork, the
BSD calls, XPC, the speech asset installer and endpoint literals — across all of
`Sources/` names nine files: the four in `UttrflowAccount`, the three onboarding files in
the app shell, the tokenizer install, and `Sources/UttrflowAI/HTTPCleanupModel.swift`,
which is inside `#if UTTRFLOW_CLOUD` from its first line to its last. Two developer CLIs
name it too and ship in nothing. Every other module under `Sources/` has none, and that is
what the audit's first check asserts.

The clean-up engine is the only one of those the dictation path runs through, and it is
compiled out.

That the flag is genuinely off in the shipped build is confirmed from the artefact, not
from reading the `#if`:

```
$ nm -a .build/arm64-apple-macosx/debug/Uttrflow | swift demangle | grep -c 'UttrflowAI.HTTPCleanupModel'
0
$ nm -a .build/.../UttrflowAI.build/HTTPCleanupModel.swift.o | swift demangle \
    | grep -v 'FORCE_LOAD\|reflection_version\|ltmp\|module_hash'
(nothing)
```

The object file exists and contains nothing but autolink stubs — not one symbol from
the source it was compiled from. The only symbols in the
whole binary that mention the cloud at all are the `cloudEndpoint:` argument labels on
`TextTransformers.all` and `.router` — the parameter survives, the engine does not. A
caller that passes an endpoint to a non-cloud build gets it ignored, which is asserted
in `Tests/UttrflowAITests/OfflineGuaranteeTests.swift` rather than left to inspection.

### Dependencies: the model downloaders, and MLX's distributed backend

The audit reads undefined symbols out of every object the app links, against a family of
networking names rather than `URLSession` alone — Foundation's stack, Network.framework's
C entry points, CFNetwork, the BSD calls, XPC, and the system speech asset installer.
Widening it that far is what found the last row, which `urlsession` alone could not see:

| Module | What can reach the network | In the app? |
|---|---|---|
| `Hub` (swift-transformers) | `URLSession` | **yes** — the speech model's downloader |
| `HuggingFace` (swift-huggingface) | `URLSession` | **yes** — the suggestion model's downloader |
| `EventSource` | `URLSession` | yes — pulled in by MLX beside `HuggingFace` |
| `UttrflowLocalModel` | `URLSession`, in the two files that build the hub client | yes — the suggestion model |
| `UttrflowAccount`, and the app shell's onboarding | `URLSession`, `NWListener`, `NWPathMonitor` | yes — sign-in, and the banner that says why it failed |
| `UttrflowSpeech` | `URLSession` in the tokenizer install; `AssetInventory` in the Apple backend | yes |
| `Cmlx` (MLX's C++ core) | `socket`, `connect`, `getaddrinfo` in `mlx/distributed/jaccl/utils.cpp` | yes — see below |
| `WhisperKit`, `ArgmaxCore`, `Tokenizers`, `Jinja`, `Crypto`, `yyjson`, every other Uttrflow module, collections | nothing | yes |

**MLX's distributed backend is linked and unreachable.** `Cmlx` compiles MLX's multi-host
support, so the app binary contains the BSD socket calls whether or not anything uses
them, and mlx-swift exposes no build flag that drops it. Those calls run only from
`mlx_distributed_init`, no Uttrflow source names it, and the audit's source check fails on
any that does — which is the only claim available here, since the code cannot be removed.
mlx-swift's own Swift surface has no distributed API, so reaching it would mean calling
the C symbol directly.

`swift-crypto` is linked but is pure computation — Hub uses it to hash downloaded files.
`ArgmaxCore.ModelDownloader` wraps Hub and is never instantiated anywhere in this
build: it is linked and unreachable.

So every model download the shipping app is capable of making goes through `Hub` for the
speech model or `HuggingFace` for the suggestion model. Hub is reached from exactly two
places; the suggestion model's path is in *The suggestion model* below.

### When Hub runs

**1. Installing a speech model — deliberate, and not on the dictation path.**
`FileSystemSpeechModelStore.whisperKit()` builds a downloader around `WhisperKit.download`.
It runs only when something calls `store.install(_:onProgress:)`, which today is only
`uttrflow-dev models install`. The app itself never calls it (see *Nothing installs the
model* below). Loading a model passes `download: false`, so a missing model is an error
rather than a silent 646 MB transfer mid-dictation; `offline_audit.sh` guards that.

**2. Loading the tokenizer — accidental, and squarely on the dictation path.** This is
the one real hole, below.

`HubApi` also starts an `NWPathMonitor` to decide whether to use its offline mode. That
observes the interface state; it opens nothing. It did not trip the SIGKILL profile.

## The pipeline runs offline: the evidence

`uttrflow-dev transcribe <file>` is the closest runnable slice of the dictation path:
read audio → resample to canonical → WhisperKit → `TextTransformers.router()` → output.
It is the same `AudioSamples`, the same `BackedSpeechEngine` and the same router the app
builds, with a file standing in for the microphone.

```
$ sandbox-exec -f kill-on-net.sb ./uttrflow-dev transcribe offline-probe.aiff

So the offline audit is working. No network at all.

  as heard     Um so the offline audit is a working. No network at all.
  audio        3.49s
  engine ready 4.29s
  transcribed  0.82s  (4.2× real time)
  tidied by    foundationModels in 1.65s
  language     en
  segments     2
  memory       0.01GB idle → 0.12GB ready → 0.18GB peak
EXIT=0
```

Exit 0 under a profile that kills on the first network syscall. Speech-to-text ran,
Apple's Foundation Models ran, and neither reached for anything. The audio was
synthesised locally with `say`, so even the fixture involved no network.

One thing worth knowing before somebody files a bug about it: the *first* offline run
after the model is installed took **301.91s** to reach "engine ready". The second took
**4.09s**. That is Core ML compiling the model for the Neural Engine, not a network
timeout — it happens under the SIGKILL profile, which a timeout could not.

### The test suite, offline

```
$ sandbox-exec -f deny-net.sb xcrun swift test --disable-sandbox
✔ Test run with 579 tests in 83 suites passed after 0.292 seconds.
EXIT=0
```

Use the plain `(deny network*)` profile for this, not the SIGKILL one: SwiftPM's own
build machinery talks to itself over local sockets, which macOS classifies as network
and which would kill the build before a single test ran. `--disable-sandbox` is needed
for the same reason — SwiftPM sandboxes manifest evaluation itself, and sandboxes do
not nest.

## The tokenizer: a hole this audit found, and the install now fills

`download: false` governs the *model*. It does not govern the tokenizer, so the install
fetches the tokenizer itself and `tokenizerFolder` is pinned at the model folder —
`TokenizerDownload` writes `tokenizer.json` and `tokenizer_config.json` beside the weights
during `install`, `isInstalled` is false until both are there, and `load()` refuses to start
without them. `Docs/speech-engines.md` § Keeping WhisperKit off the network says how that is
arranged; what follows is the measurement that asked for it.

After loading the model, WhisperKit calls `loadTokenizerIfNeeded`, which looks for
`tokenizer.json` in the model folder and in Hub's cache — and, failing that,
**downloads it from Hugging Face**. When this audit ran, Uttrflow passed no
`tokenizerFolder`, so Hub's cache was its default: `~/Documents/huggingface/`. That
directory is not the model store. The store did not create it, did not count it in
`isInstalled`, and did not delete it in `remove`.

On the machine this audit ran on, the two were in different places and were fetched at
different times:

```
~/Library/Application Support/Uttrflow/Models/openai_whisper-large-v3-v20240930_turbo_632MB/
    AudioEncoder.mlmodelc  MelSpectrogram.mlmodelc  TextDecoder.mlmodelc
    TextDecoderContextPrefill.mlmodelc  config.json  generation_config.json
    ← no tokenizer.json.  Written 19:19–19:27 by `models install`.

~/Documents/huggingface/models/openai/whisper-large-v3/
    tokenizer.json  tokenizer_config.json  config.json
    ← written 19:30, by the first transcription.
```

So `models install` reported success, `isInstalled` said yes, and the tokenizer was still
missing. It arrived on the first transcription — over the network.

Proved by hiding only that directory and changing nothing else:

```
$ sandbox-exec -f 'deny network* + deny read ~/Documents/huggingface' \
    ./uttrflow-dev transcribe offline-probe.aiff
EXIT=137
```

Killed. With the tokenizer cache visible, the identical command under the identical
profile exited 0. The difference between the two runs was one directory, and it was worth
a network call on the dictation path.

**Who it bit.** Anyone who installed the model and went offline before dictating once.
That included the intended first-run story — download on first launch, work offline
afterwards — if the user quit between the download and their first dictation. It bit a
side-loaded or restored-from-backup model store too, which is why an install made by an
older build is repaired rather than trusted.

**What they saw.** The dev tool reported
`modelLoadFailed(description: "Download failed: …")`. In the app the same error became
`SpeechEngineError.modelLoadFailed`, so the user got *"Speech recognition couldn't
start. Try again, or reinstall it from Settings."* — a complete sentence, but it named
the wrong cause and offered `.retry`, which failed identically every time.

**The fix landed in the store rather than the backend**, which is where the gap was.
`SpeechModelStore.missingComponents(of:)` treats the tokenizer as a component of its own,
answered by `TokenizerAssets.arePresent(in:)`, so `isInstalled` means what it says;
`install` fetches every missing component and throws if one did not arrive; and
`WhisperKitBackend` passes `tokenizerFolder: modelFolder`, so the search never reaches Hub's
cache. `FileSystemSpeechModelStoreTests` pins the repair of an install made by a build that
predates all of this.

`offline_audit.sh` § Tokenizer takes the pass branch on that pinned folder — "a tokenizer
folder is pinned, so loading cannot fall back to the hub" — and fails if it ever disappears,
so the fix cannot be quietly undone. The KNOWN GAP note it prints instead is the branch that
no longer runs.

## No model, no network

Tested, because it is the real first-run failure.

**Trying to install with no connection** — a variant that was genuinely absent, so
nothing already on disk was at risk:

```
$ sandbox-exec -f deny-net.sb ./uttrflow-dev models install --model openai_whisper-base
Installing openai_whisper-base — 147 MB
Error: modelDownloadFailed(description: "Download failed: … Operation not permitted")
EXIT=1
```

The store's clean-up works: no half-installed directory was left behind. In the app that
error reads *"Setup couldn't be completed. Check your connection and try again."* with a
`.downloadSpeechModel` action — the right sentence for the situation.

**Dictating with no model** stops before the network is ever needed:

```
$ sandbox-exec -f 'kill-on-net + deny read ~/Library/Application Support/Uttrflow' \
    ./uttrflow-dev transcribe offline-probe.aiff
openai_whisper-large-v3-v20240930_turbo_632MB is not installed. Run: uttrflow-dev models install
```

In the app the same condition raises `.modelNotInstalled` — *"Speech recognition needs
to finish setting up before you can dictate."* with a `.downloadSpeechModel` action.
No hang, no crash.

### The model download path routes through onboarding

The **Download**/**Finish Setup** button for `.downloadSpeechModel` reopens the installer.
`DockView` sends the recovery action through `DockPanelController`, and
`AppDelegate.wireInterface()` assigns the handler. `AppDelegate.perform(_:)` routes an
absent model straight to `show(.onboarding)`, whose setup page calls `beginInstall()` on
the injected installer and shows progress — the same surface a first run uses.

When the model was installed but failed to load, `perform(_:)` calls `repairSpeechModel()`
first: it removes the broken install and resets readiness to `.notInstalled` before showing
onboarding, so setup downloads a fresh copy instead of retrying the same failed load.

This matters after somebody has dismissed onboarding. **Finish Setup** reopens onboarding's
setup page and starts the install from there, so dismissing onboarding once does not strand
the user without a way back into the installer. The offline promise remains conditional on
the model being installed, but the recovery action itself now gets it installed rather than
only pointing at Settings.

### Startup now says what happened

At launch, `AppDelegate.loadSpeechModel()` first asks the model store whether the default
model is installed. If it is absent, it records `.notInstalled` and returns; it does not
claim that the app is ready. If the files are present, it reports `.loading` while it
awaits `DictationPipeline.prepare()`.

`DictationPipeline.prepare()` now catches a failed speech-engine load, keeps `isReady`
false, and publishes a failed state when no dictation is in progress. The app maps a
successful preparation to `.ready`, an unsuccessful one to `.loadFailed` while the files are
still on disk and to `.notInstalled` when they are not, so the menu bar can say *"Getting
ready…"*, *"Speech model didn't load"* or *"Speech model not downloaded"* instead of leaving
the user with a false *"Ready"*. A missing model is still a setup state rather than a
startup exception, but it is no longer silently discovered only after the first keypress.

## The suggestion model

`MLXCandidateScorer.prepare()` loads the suggestion model, and the app calls it whenever
AI suggestions is turned on or the weights are loaded again. It used to load through
`loadModelContainer(from: #hubDownloader(), …)`. The hub client asks the model host for the
repository's file list before it looks in the cache, and its cache-only fast path needs a
metadata file the cache on disk did not have, so every load on an online Mac opened an IP
connection even with every file already present. Offline the request failed and the load fell
back to the cache, which is why nothing looked broken (#380).

`LocalModel.weightsDirectory(cache:downloader:onProgress:)` now decides first. When
`CachedSnapshot.complete` finds `snapshots/<LocalModel.revision>/` with `config.json`,
`tokenizer.json` and `tokenizer_config.json` present, every `*.safetensors` file exactly as long
as its own header says, every numbered shard present, and the weights at least nine tenths of
the model's recorded download, the model loads from that directory and the hub is never
constructed. Anything less goes to the hub exactly as before, so a first download still works.
The shard index is not trusted as a list of files: one candidate's index names two shards
while its repository holds one.

A model already whole on disk is never refreshed from the hub; a new revision arrives only
when the cache is missing or incomplete.

`CachedSnapshotTests` pins it with a downloader that counts and refuses every call, and
`offline_audit.sh` § Suggestion model fails if a load takes the hub downloader directly again.

Measured with `uttrflow-bakeoff gpu-memory --passes 1` against a cache holding the whole
gemma-3-4b-it-qat-4bit snapshot, under `kill-on-net.sb`:

| build | exit |
|---|---|
| before | 137, killed before "loaded" |
| after | 0 |

## What the audit checks

`Scripts/offline_audit.sh` runs in `make verify`, after `build`, because two of its checks
read object files. Seven checks, each default-deny: every module and every linked object is
covered unless it is named, with the reason, in the script. That shape matters more than
the patterns do — the version this replaced listed the seven modules to look at, and the
clipboard, the history, the dictionary, the settings, the two suggestion stores and the UX
were unchecked simply by not being on the list.

| # | What it asserts | How |
|---|---|---|
| 1 | No file under `Sources/` names a way to reach the network, except `UttrflowAccount` and eight named files | Source grep over Foundation's stack, Network.framework in both spellings, CFNetwork, the BSD calls, XPC, the speech asset installer, `mlx_distributed`, and endpoint literals |
| 1b | No file reads a URL through `Data(contentsOf:)` or its siblings outside the files known to read local paths | Source grep; see the limits below for what this can and cannot say |
| 2 | The hosted clean-up model is wrapped in `#if UTTRFLOW_CLOUD` from first line to last, and no target defines the flag | `head`/`tail` on the file, grep on `Package.swift` |
| 3 | Loading a speech model still passes `download: false`, and the model hub is named only where the install runs | Source grep over the whole tree |
| 4 | A `tokenizerFolder` is pinned, so loading cannot fall back to the hub | Source grep |
| 5 | The suggestion model checks its cache before asking the hub, and no load takes the hub downloader directly | Source grep |
| 6 | The updater is imported in one file in the app shell, and one target depends on it | Source grep, grep on `Package.swift` |
| 7 | No linked object can reach the network unless its source file was allowed one, and no new network-capable dependency has appeared | `nm -uA` over every object in the app's link file list |

Check 7 needs the built binary. In CI — and with `--require-binary` — a missing one is a
failure, because it is the only check that can see a dependency's network call, and
skipping it quietly is how one would ship. Locally a bare run says so and carries on, so
that a contributor mid-change gets the source checks in a second or two.

The whole audit costs a couple of seconds beyond `nm`, and a few more than the version it
replaced: one `nm -uA` pass over every linked object, rather than one per module, is what
keeps the per-file resolution affordable in a gate.

## What this does not prove

- **The microphone and the insertion steps were not exercised offline.** `AVAudioCaptureEngine`
  needs a real hold-to-talk gesture and `TextInsertionCoordinator` needs a focused text
  field in another app; neither can be driven headlessly, and the sandbox cannot grant
  the TCC permissions they require. Both are argued to be network-free from the source
  audit only: `UttrflowAudio` and `UttrflowInput` contain no network call site, and
  `offline_audit.sh` keeps it that way. The sandboxed run does exercise the second half
  of capture — `AudioFileReader` hands its samples through the same `AudioResampler` the
  microphone path uses — but a full hold-key-to-inserted-text run offline has not been
  observed.
- **Apple's frameworks are taken at their word.** `FoundationModels`, `Speech` and
  `CoreML` are closed. The sandboxed run shows that none of them opened a socket *from
  this process*; work they hand to a system daemon over XPC is outside the sandbox and
  outside what this can see. For `FoundationModels` that is Apple's documented
  on-device guarantee, not something measured here.
- **`AppleSpeechBackend` is not offline-safe on first use, and was not tested.** Its
  `load()` calls `AssetInventory.assetInstallationRequest(...).downloadAndInstall()`,
  which fetches a system speech asset, and `transcribe()` calls `load()`. That is a
  network call on the dictation path whenever the locale's asset is absent — it returns
  immediately once `status` is `.installed`. It is off the default path
  (`EngineConfiguration.default.speech` is `.whisperKit`) but one settings change away:
  *Built-in speech recognition* selects it. The audit now names it on every run, as a
  known gap rather than a sanctioned exception, because the fix is a product decision
  about what the user is told — `WhisperKitBackend` has `download: false` for exactly
  this, and Apple's asset API offers no equivalent.
- **Reading a URL cannot be told from fetching one.** `Data(contentsOf:)` and
  `String(contentsOf:)` fetch a remote URL synchronously inside Foundation, so the calling
  module names no networking type and its object file carries no networking symbol. Both
  halves of the audit are blind to it. What the audit does instead is name every file that
  uses one today, so a new one has to be argued for; it does not establish that the
  existing ones are local, which was done by reading them.
- **A dependency is judged whole, not per file.** The per-object check applies to
  Uttrflow's own modules, where the audit has a file-level claim to make. For somebody
  else's source tree it asserts only that the set of network-capable dependencies has not
  grown, which says nothing about when any of them runs.
- **Sparkle is not inspected.** It fetches an appcast and an archive; that is the feature,
  so reading the framework would only confirm it. What is checked is that it can be driven
  from one file in the app shell and that no library target links it, which is what keeps
  the updater off every path a dictation, a clip or a history entry runs through.
- **Only the paths that ran were tested.** A sandboxed run proves what happened, not
  what would happen on a different model, locale or failure branch. That is what
  `offline_audit.sh` is for.

## Summary

The app is offline-safe on the dictation path with WhisperKit, which is the default
recogniser: Uttrflow's own code, the clean-up engines, the router and the model load all
completed under a profile that kills the process for touching the network, and the
tokenizer hole that was open here is closed by the install pinning a `tokenizerFolder`.

One gap is open, and the audit names it on every run rather than passing over it: with
*Built-in speech recognition* selected, the first dictation in a locale whose system
speech asset is not installed downloads that asset. See *What this does not prove*.
