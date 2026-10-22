#!/bin/bash
set -euo pipefail
source "$(dirname -- "${BASH_SOURCE[0]}")/common.sh"
REFOCUS_APP="$REFOCUS_ROOT/dist/Refocus.app"
# Recreate the generated bundle so renamed files or old build metadata cannot linger.
rm -rf "$REFOCUS_APP"
mkdir -p "$REFOCUS_APP/Contents/MacOS" "$REFOCUS_APP/Contents/Resources" "$REFOCUS_APP/Contents/Library/LaunchDaemons"
compile_binaries() {
    compile_core
    "${REFOCUS_SWIFT[@]}" -I "$REFOCUS_BUILD" -L "$REFOCUS_BUILD" -lRefocusCore \
        "$REFOCUS_ROOT"/Sources/RefocusApp/*.swift -o "$REFOCUS_BUILD/Refocus"
    "${REFOCUS_SWIFT[@]}" -I "$REFOCUS_BUILD" -L "$REFOCUS_BUILD" -lRefocusCore \
        "$REFOCUS_ROOT"/Sources/RefocusHelper/*.swift -o "$REFOCUS_BUILD/RefocusHelper"
}
case "${1:-}" in
    --universal)
        for REFOCUS_TARGET in arm64 x86_64; do set_architecture "$REFOCUS_TARGET"; compile_binaries; done
        for REFOCUS_BINARY in Refocus RefocusHelper; do
            lipo -create "$REFOCUS_ROOT/.build/local/arm64/$REFOCUS_BINARY" "$REFOCUS_ROOT/.build/local/x86_64/$REFOCUS_BINARY" \
                -output "$REFOCUS_APP/Contents/MacOS/$REFOCUS_BINARY"
        done
        ;;
    "")
        compile_binaries
        cp "$REFOCUS_BUILD/Refocus" "$REFOCUS_APP/Contents/MacOS/Refocus"
        cp "$REFOCUS_BUILD/RefocusHelper" "$REFOCUS_APP/Contents/MacOS/RefocusHelper"
        ;;
    *) printf 'Usage: bash scripts/build.sh [--universal]\n' >&2; exit 2 ;;
esac
# Build-time tools execute on this Mac, independent of the app's target architectures.
set_architecture "$(uname -m)"
cp "$REFOCUS_ROOT/Resources/Info.plist" "$REFOCUS_APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $REFOCUS_VERSION" "$REFOCUS_APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $REFOCUS_BUILD_NUMBER" "$REFOCUS_APP/Contents/Info.plist"
cp "$REFOCUS_ROOT/Resources/org.refocus.app.helper.plist" "$REFOCUS_APP/Contents/Library/LaunchDaemons/"
cp "$REFOCUS_ROOT/README.md" "$REFOCUS_APP/Contents/Resources/README.md"
mkdir -p "$REFOCUS_APP/Contents/Resources/docs"
cp "$REFOCUS_ROOT/docs/"*.md "$REFOCUS_APP/Contents/Resources/docs/"
cp "$REFOCUS_ROOT/CONTRIBUTING.md" "$REFOCUS_APP/Contents/Resources/CONTRIBUTING.md"
cp "$REFOCUS_ROOT/CHANGELOG.md" "$REFOCUS_APP/Contents/Resources/CHANGELOG.md"
cp "$REFOCUS_ROOT/LICENSE" "$REFOCUS_APP/Contents/Resources/LICENSE"
cp "$REFOCUS_ROOT/SITE_ALIASES.md" "$REFOCUS_APP/Contents/Resources/SITE_ALIASES.md"
"${REFOCUS_SWIFT[@]}" "$REFOCUS_ROOT/scripts/make-icon.swift" -o "$REFOCUS_BUILD/MakeIcon"
REFOCUS_ICONSET="$REFOCUS_ROOT/.build/local/Refocus.iconset"
"$REFOCUS_BUILD/MakeIcon" "$REFOCUS_ICONSET"
iconutil -c icns "$REFOCUS_ICONSET" -o "$REFOCUS_APP/Contents/Resources/AppIcon.icns"
cp "$REFOCUS_ICONSET/icon_256x256.png" "$REFOCUS_ROOT/dist/Refocus-icon.png"
xattr -cr "$REFOCUS_APP"
REFOCUS_SIGNER="${REFOCUS_SIGN_IDENTITY:--}"
REFOCUS_TIMESTAMP=(--timestamp)
if [ "$REFOCUS_SIGNER" = "-" ]; then REFOCUS_TIMESTAMP=(--timestamp=none); fi
codesign --force --sign "$REFOCUS_SIGNER" --options runtime "${REFOCUS_TIMESTAMP[@]}" \
    --identifier org.refocus.app.helper "$REFOCUS_APP/Contents/MacOS/RefocusHelper"
codesign --force --sign "$REFOCUS_SIGNER" --options runtime "${REFOCUS_TIMESTAMP[@]}" "$REFOCUS_APP"
codesign --verify --strict --deep "$REFOCUS_APP"
ditto -c -k --norsrc --noextattr --noqtn --noacl --keepParent "$REFOCUS_APP" "$REFOCUS_ROOT/dist/Refocus-macOS.zip"
printf 'Built and signed: %s\n' "$REFOCUS_APP"
