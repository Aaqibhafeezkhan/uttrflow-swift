#!/usr/bin/env bash
# Proves the offline audit's tokenizer check is a real gate: removing the pinned
# tokenizerFolder must fail it, not just note it as a known gap. Runs against a disposable
# copy of the tree with --no-build, so it needs no built app, no model, and never touches
# this checkout. CI is unset for both runs, since it would demand the binary --no-build skips.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
backend_relative="Sources/UttrflowSpeech/WhisperKitBackend.swift"
test_root="$(mktemp -d)"
trap 'rm -rf "$test_root"' EXIT

copy="$test_root/repo"
mkdir -p "$copy"
tar -C "$repo_root" --exclude='.git' --exclude='.build' --exclude='.claude' -cf - . | tar -C "$copy" -xf -

# Sanity check: the unmodified copy must pass, so a later failure is known to come from
# the removed pin and not from something else already broken in the tree.
if ! (cd "$copy" && env -u CI ./Scripts/offline_audit.sh --no-build >/dev/null 2>"$test_root/baseline.log"); then
    echo "error: the offline audit does not pass on an unmodified copy of the tree" >&2
    cat "$test_root/baseline.log" >&2
    exit 1
fi

backend="$copy/$backend_relative"
[[ -f "$backend" ]] || { echo "error: $backend_relative is missing from the copy" >&2; exit 1; }
if ! grep -q 'tokenizerFolder: modelFolder,' "$backend"; then
    echo "error: the injection site 'tokenizerFolder: modelFolder,' is gone from $backend_relative; update this test" >&2
    exit 1
fi
sed -i '' '/tokenizerFolder: modelFolder,/d' "$backend"

log="$test_root/removed.log"
if (cd "$copy" && env -u CI ./Scripts/offline_audit.sh --no-build >"$log" 2>&1); then
    echo "error: the offline audit passed with no tokenizerFolder pinned" >&2
    cat "$log" >&2
    exit 1
fi
if ! grep -Fq 'does not pin a tokenizerFolder' "$log"; then
    echo "error: the audit failed for a different reason than the missing pin" >&2
    cat "$log" >&2
    exit 1
fi

printf 'offline audit tokenizer test passed\n'
