# Installing a speech model, one component at a time

`FileSystemSpeechModelStore` in `Sources/UttrflowSpeech/SpeechModelStore.swift` owns where
speech models live on disk and how they get there. The download itself is injected, so
everything else — where files go, what counts as installed, refusing to re-download, cleaning
up a failed install — is testable against a temporary directory with no network.

## Two components, fetched separately

The weights and the tokenizer come from different repositories and go missing independently,
so the store asks for them one at a time instead of treating an install as all or nothing.

## Installed means "everything needed to transcribe with it"

The weights alone are not enough, and treating them as enough made `isInstalled` a lie.
WhisperKit will quietly fetch a missing tokenizer from Hugging Face the first time somebody
dictates — on a plane, that is an unrecoverable failure reported as a load error rather than
the missing download it actually is. Answering `false` is what puts the offer to install back
in front of the user, which is the whole remedy for an install made by a build that only
fetched weights.

An empty directory is what a cancelled download leaves behind, and is likewise not installed:
treating it as installed would fail later, further from the cause.

Weights are detected by the model's manifest (`SpeechModel.weightFiles`, read through
`WeightsAssets`): every file in the model's folder at the pinned commit — each `.mlmodelc` bundle's
`coremldata.bin`, `model.mil`, `metadata.json`, `analytics/coremldata.bin` and
`weights/weight.bin`, the optional `TextDecoderContextPrefill.mlmodelc`, `config.json` and
`generation_config.json` — each at least one byte. A bundle without its `model.mil` fails to load
with "Failed to parse ML Program", so a folder missing any listed file is not installed.
`isIncomplete(_:)` names that case: the folder is there and a file is not, so the app offers to
download it again rather than to load it. The manifest adds up to `downloadBytes`, and a test holds
it there, so a manifest that forgets a file fails before it ships.

The size check is presence and non-empty, not the recorded size or digest: the store answers on
every menu draw, and hashing 600 MB there is not affordable. Every file is hashed before it is moved
into staging, and staging below is what keeps a half-fetched one out of the model's directory.

## Missing components are ordered weights-first

The weights are the wait: they own the progress bar, so asking for them first means the bar
starts moving straight away.

## Installing fetches only what is missing

That is what keeps an install made by an earlier build cheap to repair: those have the weights
and no tokenizer, and re-downloading six hundred megabytes to add three would be a poor way to
apologise.

A download that reports success and produces nothing is checked for on the spot, rather than
being discovered a launch later as a model that will not load.

## Weights are staged, then moved in whole

The weights download into `<root>/.partial/<variant>/`, never into the model's directory. Only
when every weight file is there are they moved in: a tokenizer already in the model's directory is
copied into staging, not moved, so the model's directory keeps its own tokenizer until staging
replaces the whole directory in one `replaceItemAt`. A process killed at any point before that —
including between the copy and the swap — leaves the model's directory as it was, so nothing
half-fetched is ever mistaken for a model.

The model root, staging folders, installed model folders and tokenizer files are marked
`isExcludedFromBackup`. They are public downloaded data and can be fetched again, so backup tools
that honour Finder's exclusion flag should not spend space carrying them.

## Unwinding a failed fetch, in proportion

| Failed component | What is removed        | Why |
|------------------|------------------------|-----|
| weights, with an error | nothing; staging is kept | the files already fetched let asking again resume instead of restarting, and the model's directory was never touched |
| weights, reported done but incomplete | the staging directory | what it holds is not a model and would not become one by resuming |
| tokenizer        | the tokenizer only     | the weights beside it may be six hundred megabytes the user has already waited for, and are still perfectly good |

`remove(_:)` discards staging along with the model.

## Checking the disk before downloading

The default model is about 650 MB, and a disk too full to hold it would otherwise fail partway
through and be reported as a connection problem the user cannot fix by retrying.

- Before fetching the weights, the store reads `volumeAvailableCapacityForImportantUsageKey` for
  the volume under its root and refuses with `SpeechEngineError.notEnoughSpace` when that is less
  than the rest of the download plus a 200 MB margin. Bytes already staged by an earlier attempt
  count towards the download, so a resume asks only for what is left.
- A volume that cannot report its capacity is not refused; the download is tried.
- A download, move or tokenizer fetch that fails with `NSFileWriteOutOfSpaceError` or `ENOSPC`,
  directly or as an underlying error, raises the same failure. Its message names the space needed
  rather than asking the user to check their connection; every other failure keeps that wording.

## Pinned model files

Both halves of the model are fetched from `huggingface.co/<repository>/resolve/<commit>/<file>`.
The CoreML weights use `SpeechModel.weightsRevision`, `weightsRepository`, and `weightFiles`; the
tokenizer uses `tokenizerRevision`, `tokenizerRepository`, and `tokenizerDigests`. Each weight file
is downloaded to a temporary file, counted, hashed, tightened, and only then moved into staging.
Each tokenizer file is likewise checked before it is written. A pinned commit says which file to
fetch; only the size and digest say it is the file that was pinned.

The app does not call `WhisperKit.download` for installs. That downloader has no revision argument
for these weights and can fall back to the person's own Hugging Face token. Uttrflow fetches public
files directly instead, with `huggingface.co` and the commit named in source.

**To bump a weight revision**, take the CoreML repository's current commit and the metadata for
every file in the model's folder:

```bash
curl -s https://huggingface.co/api/models/argmaxinc/whisperkit-coreml \
  | python3 -c 'import sys,json;print(json.load(sys.stdin)["sha"])'
curl -s "https://huggingface.co/api/models/argmaxinc/whisperkit-coreml/tree/<commit>/<variant>?recursive=1" \
  | python3 -c 'import sys,json; [print(i["path"], i["size"], i.get("lfs", {}).get("oid")) for i in json.load(sys.stdin)]'
```

Put the commit in `weightsRevision`, and put every file's `size` and SHA-256 in `weightFiles`: the
LFS `oid` for a file stored in LFS, and `shasum -a 256` of the downloaded file for one that is not
(`model.mil`, `metadata.json`, `config.json`), whose `oid` is a git hash and not a digest.

**To bump a tokenizer revision**, take the repository's current commit and the files' digests:

```bash
curl -s https://huggingface.co/openai/whisper-base | head -0   # see the repository
curl -s https://huggingface.co/api/models/openai/whisper-base | python3 -c 'import sys,json;print(json.load(sys.stdin)["sha"])'
curl -sL https://huggingface.co/openai/whisper-base/resolve/<commit>/tokenizer.json | shasum -a 256
```

Put both in `SpeechModel`, and say in the pull request what changed in the tokenizer and why the
app should follow it. `Scripts/offline_audit.sh` fails on `resolve/main/`, so a revision cannot
quietly become a branch again.

## `FileManager`

`FileManager` is not `Sendable`, and the shared instance is documented as safe for the file
operations used here. Tests run against real temporary directories, which is more faithful
than a substitute would be.
