#!/usr/bin/env bash
#
# Picks the standalone square Google mark out of an extracted signin-assets archive.
#
# The pack's internal layout is Google's to change, and it has changed before, so this
# searches for the mark rather than assumes a path. What is wanted is a standalone square
# G with no wording baked in, which is the only shape that can be scaled to a 16pt button.
#
# The current pack has no bare G, only tiles, so the caller asks for a theme and lifts the G
# off a light and a dark tile (Scripts/lift-google-mark.swift).
#
# Usage:  ./Scripts/select-google-mark.sh <extracted-archive-dir> [Light|Dark]
# Prints the chosen file's path, or nothing (exit 0) if none is recognisable.
set -euo pipefail

DIR="$1"
THEME="${2:-Light}"

CANDIDATES="$(find "$DIR" -type f -iname '*.png' \
    ! -iname '*disabled*' ! -iname '*pressed*' ! -iname '*focus*')"

# The legacy layout named the file after the mark itself.
MARK="$(printf '%s\n' "$CANDIDATES" | grep -iE 'g[-_]?logo|logo[-_]?g|google[-_]?g\b|/g\.png$' | sort | head -1 || true)"

if [[ -z "$MARK" ]]; then
    # The current layout names each variant by its attributes instead, e.g. a path
    # component such as "Theme=Neutral, Show text=No, Shape=Square, Platform=iOS.png".
    # A square shape with no text is a standalone mark regardless of theme or platform;
    # the largest scale is taken so the lifted G stays sharp, and sorting keeps the pick deterministic.
    SQUARE="$(printf '%s\n' "$CANDIDATES" | grep -i 'shape=square' | grep -i 'show text=no' || true)"
    THEMED="$(printf '%s\n' "$SQUARE" | grep -i "theme=$THEME" || true)"
    # A pack without the asked-for theme still offers its other square marks.
    [[ -n "$THEMED" ]] || THEMED="$SQUARE"
    MARK="$(printf '%s\n' "$THEMED" \
        | awk 'NF { scale = 1; if (match($0, /@[0-9]x/)) scale = substr($0, RSTART + 1, 1); print scale "\t" $0 }' \
        | sort -t "$(printf '\t')" -k1,1nr -k2,2 \
        | head -1 \
        | cut -f2- || true)"
fi

printf '%s' "$MARK"
