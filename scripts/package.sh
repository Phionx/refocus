#!/bin/bash
set -euo pipefail
source "$(dirname -- "${BASH_SOURCE[0]}")/common.sh"
case "${1:-}" in
    "") bash "$REFOCUS_ROOT/scripts/build.sh" --universal ;;
    --use-built-app) ;;
    *) printf 'Usage: bash scripts/package.sh [--use-built-app]\n' >&2; exit 2 ;;
esac
REFOCUS_APP="$REFOCUS_ROOT/dist/Refocus.app"
REFOCUS_ASSET="Refocus-$REFOCUS_VERSION-macOS"
REFOCUS_ACTUAL_VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$REFOCUS_APP/Contents/Info.plist")"
REFOCUS_ACTUAL_BUILD="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$REFOCUS_APP/Contents/Info.plist")"
if [ "$REFOCUS_ACTUAL_VERSION" != "$REFOCUS_VERSION" ] || [ "$REFOCUS_ACTUAL_BUILD" != "$REFOCUS_BUILD_NUMBER" ]; then
    printf 'Built app does not match VERSION / BUILD_NUMBER.\n' >&2; exit 1
fi
for REFOCUS_BINARY in Refocus RefocusHelper; do
    lipo "$REFOCUS_APP/Contents/MacOS/$REFOCUS_BINARY" -verify_arch arm64 x86_64
done
codesign --verify --strict --deep "$REFOCUS_APP"
"${REFOCUS_SWIFT[@]}" "$REFOCUS_ROOT/scripts/audit-privacy.swift" -o "$REFOCUS_BUILD/PrivacyAudit"
# Local APFS may retain protected provenance attributes. The ZIP explicitly excludes
# metadata. Audit the actual DMG read-only; publish clean CI-built assets for releases.
"$REFOCUS_BUILD/PrivacyAudit" "$REFOCUS_APP" --content-only
REFOCUS_STAGE="$(mktemp -d "$REFOCUS_ROOT/dist/.package.XXXXXX")"
REFOCUS_MOUNT="$REFOCUS_STAGE/volume"
cleanup() {
    if mount | /usr/bin/grep -Fq " on $REFOCUS_MOUNT ("; then hdiutil detach -quiet "$REFOCUS_MOUNT" || return; fi
    rm -rf "$REFOCUS_STAGE"
}
trap cleanup EXIT
ditto -c -k --norsrc --noextattr --noqtn --noacl --keepParent \
    "$REFOCUS_APP" "$REFOCUS_ROOT/dist/$REFOCUS_ASSET.zip"
# ZIP metadata must not contain resource-fork/extended-attribute sidecars.
if unzip -Z1 "$REFOCUS_ROOT/dist/$REFOCUS_ASSET.zip" | /usr/bin/grep -Eq '(^|/)(__MACOSX|\._|\.DS_Store)'; then
    printf 'Unexpected metadata sidecar in release ZIP.\n' >&2; exit 1
fi
mkdir "$REFOCUS_STAGE/source" "$REFOCUS_MOUNT"
unzip -q "$REFOCUS_ROOT/dist/$REFOCUS_ASSET.zip" -d "$REFOCUS_STAGE/source"
ln -s /Applications "$REFOCUS_STAGE/source/Applications"
xattr -cr "$REFOCUS_STAGE/source/Refocus.app"
codesign --verify --strict --deep "$REFOCUS_STAGE/source/Refocus.app"
hdiutil create -quiet -volname "Refocus $REFOCUS_VERSION" -srcfolder "$REFOCUS_STAGE/source" \
    -noanyowners -fs HFS+ -format UDZO -ov "$REFOCUS_ROOT/dist/$REFOCUS_ASSET.dmg"
hdiutil attach -quiet -readonly -nobrowse -owners off -mountpoint "$REFOCUS_MOUNT" "$REFOCUS_ROOT/dist/$REFOCUS_ASSET.dmg"
if ! "$REFOCUS_BUILD/PrivacyAudit" "$REFOCUS_MOUNT/Refocus.app"; then
    printf 'Release metadata check failed. Use the clean GitHub Actions build if local macOS provenance cannot be removed.\n' >&2
    exit 1
fi
codesign --verify --strict --deep "$REFOCUS_MOUNT/Refocus.app"
hdiutil detach -quiet "$REFOCUS_MOUNT"
(cd "$REFOCUS_ROOT/dist" && shasum -a 256 "$REFOCUS_ASSET.dmg" "$REFOCUS_ASSET.zip" > SHA256SUMS.txt)
printf 'Packaged %s.dmg, %s.zip and SHA256SUMS.txt\n' "$REFOCUS_ASSET" "$REFOCUS_ASSET"
