#!/bin/bash
set -euo pipefail
source "$(dirname -- "${BASH_SOURCE[0]}")/common.sh"
compile_core
"${REFOCUS_SWIFT[@]}" -I "$REFOCUS_BUILD" -L "$REFOCUS_BUILD" -lRefocusCore \
    "$REFOCUS_ROOT/scripts/alias-reference.swift" -o "$REFOCUS_BUILD/AliasReference"
"$REFOCUS_BUILD/AliasReference" > "$REFOCUS_ROOT/SITE_ALIASES.md"
printf 'Updated SITE_ALIASES.md\n'
