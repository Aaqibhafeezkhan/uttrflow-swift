#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
test_root="$(mktemp -d)"
trap 'rm -rf "$test_root"' EXIT

# A representative attribute-named archive, the current Google layout: square marks with
# no baked-in text alongside worded buttons and non-square shapes that must be rejected.
current="$test_root/current"
mkdir -p \
    "$current/iOS/PNG @1x/Neutral" \
    "$current/iOS/PNG @2x/Neutral" \
    "$current/Android/PNG/Neutral" \
    "$current/Web/PNG/Light"
touch \
    "$current/iOS/PNG @1x/Neutral/Theme=Neutral, Show text=No, Shape=Square, Platform=iOS.png" \
    "$current/iOS/PNG @2x/Neutral/Theme=Neutral, Show text=No, Shape=Square, Platform=iOS.png" \
    "$current/Android/PNG/Neutral/Theme=Neutral, Show text=No, Shape=Square, Platform=Android.png" \
    "$current/Web/PNG/Light/Theme=Light, Show text=Yes, Shape=Rounded, Platform=Web.png" \
    "$current/Web/PNG/Light/Theme=Light, Show text=No, Shape=Square, Platform=Web, pressed.png"

picked="$("$repo_root/Scripts/select-google-mark.sh" "$current")"

if [[ -z "$picked" ]]; then
    echo "error: no mark recognised in the current attribute-named layout" >&2
    exit 1
fi
if [[ "$picked" == *"Show text=Yes"* ]]; then
    echo "error: picked a worded button image: $picked" >&2
    exit 1
fi
if [[ "$picked" == *"pressed"* ]]; then
    echo "error: picked an excluded interaction-state image: $picked" >&2
    exit 1
fi
if [[ "$picked" != *"Shape=Square"* ]]; then
    echo "error: picked a non-square shape: $picked" >&2
    exit 1
fi

repeat="$("$repo_root/Scripts/select-google-mark.sh" "$current")"
if [[ "$picked" != "$repeat" ]]; then
    echo "error: selection was not deterministic across platform/scale variants" >&2
    exit 1
fi

# A themed pack yields the largest light tile and, when asked, the largest dark one.
themed="$test_root/themed"
mkdir -p "$themed/PNG @1x/Light" "$themed/PNG @4x/Light" "$themed/PNG @4x/Dark"
touch \
    "$themed/PNG @1x/Light/Theme=Light, Show text=No, Shape=Square, Platform=iOS.png" \
    "$themed/PNG @4x/Light/Theme=Light, Show text=No, Shape=Square, Platform=iOS.png" \
    "$themed/PNG @4x/Dark/Theme=Dark, Show text=No, Shape=Square, Platform=iOS.png"
light_picked="$("$repo_root/Scripts/select-google-mark.sh" "$themed")"
if [[ "$light_picked" != *"PNG @4x/Light/"* ]]; then
    echo "error: the largest light tile was not picked: $light_picked" >&2
    exit 1
fi
dark_picked="$("$repo_root/Scripts/select-google-mark.sh" "$themed" Dark)"
if [[ "$dark_picked" != *"PNG @4x/Dark/"* ]]; then
    echo "error: the largest dark tile was not picked: $dark_picked" >&2
    exit 1
fi

# The legacy filename-token layout still has to work.
legacy="$test_root/legacy"
mkdir -p "$legacy"
touch "$legacy/btn_google_dark_normal_ios.png" "$legacy/google-g-logo.png"
legacy_picked="$("$repo_root/Scripts/select-google-mark.sh" "$legacy")"
if [[ "$legacy_picked" != *"google-g-logo.png" ]]; then
    echo "error: legacy g-logo naming was not recognised: $legacy_picked" >&2
    exit 1
fi

# An archive with only worded buttons and no standalone mark must be reported as empty.
only_worded="$test_root/only-worded"
mkdir -p "$only_worded"
touch "$only_worded/Theme=Light, Show text=Yes, Shape=Rounded, Platform=Web.png"
empty_picked="$("$repo_root/Scripts/select-google-mark.sh" "$only_worded")"
if [[ -n "$empty_picked" ]]; then
    echo "error: an archive with no standalone mark should select nothing, got: $empty_picked" >&2
    exit 1
fi

printf 'select-google-mark test passed\n'
