#!/bin/bash
set -euo pipefail
REFOCUS_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
REFOCUS_SDK="$(xcrun --sdk macosx --show-sdk-path)"
REFOCUS_VERSION="$(cat "$REFOCUS_ROOT/VERSION")"
REFOCUS_BUILD_NUMBER="$(cat "$REFOCUS_ROOT/BUILD_NUMBER")"
if [[ ! "$REFOCUS_VERSION" =~ ^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$ ]] || [[ ! "$REFOCUS_BUILD_NUMBER" =~ ^[1-9][0-9]*$ ]]; then
    printf 'VERSION must be a semantic version and BUILD_NUMBER must be a positive integer.\n' >&2
    exit 1
fi
set_architecture() {
    REFOCUS_ARCH="$1"
    REFOCUS_BUILD="$REFOCUS_ROOT/.build/local/$REFOCUS_ARCH"
    mkdir -p "$REFOCUS_BUILD" "$REFOCUS_ROOT/.build/local/module-cache"
    REFOCUS_SWIFT=(xcrun swiftc -sdk "$REFOCUS_SDK" -target "$REFOCUS_ARCH-apple-macosx13.0" -module-cache-path "$REFOCUS_ROOT/.build/local/module-cache" -O
        -file-prefix-map "$REFOCUS_ROOT=Refocus" -debug-prefix-map "$REFOCUS_ROOT=Refocus")
}
set_architecture "$(uname -m)"

compile_core() {
    "${REFOCUS_SWIFT[@]}" -parse-as-library -emit-library -static -emit-module \
        -module-name RefocusCore -emit-module-path "$REFOCUS_BUILD/RefocusCore.swiftmodule" \
        "$REFOCUS_ROOT"/Sources/RefocusCore/*.swift -o "$REFOCUS_BUILD/libRefocusCore.a"
}
