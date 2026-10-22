# Releasing Refocus

## Version and validate

1. Update VERSION (semantic `major.minor.patch`) and increment BUILD_NUMBER. For the pre-1.0 series, use a minor version for substantial changes or compatibility changes and a patch for fixes.
2. Add changelog notes. Run `bash scripts/update-aliases.sh` after changing the catalog.
3. Run `bash scripts/test.sh` and `bash scripts/package.sh`. Packaging builds Apple Silicon + Intel, checks the app payload, and emits:
   - `dist/Refocus-VERSION-macOS.dmg`
   - `dist/Refocus-VERSION-macOS.zip`
   - `dist/SHA256SUMS.txt`
The published download should come from GitHub Actions' clean runner, not a personal development machine. macOS may retain protected provenance metadata on local files despite `xattr -c`. Packaging rejects that metadata in the actual DMG; download the matching workflow artifact for the tagged source and upload those assets to the release. No personal settings or signing credentials are passed to CI.

4. Test the DMG on a separate Mac: drag to Applications, launch through Gatekeeper, approve the background helper, block/unblock, pause/resume, quit/force quit, and replace a prior installed version. Fixture tests do not verify the macOS approval UI.
5. Commit with a GitHub no-reply email. Create matching tag `vVERSION` and push the source and tag.
6. Create a GitHub release for that tag and attach the versioned DMG, ZIP, and checksums. Mark an early ad-hoc build as a pre-release and explain the first-install approval steps. Binaries belong in release assets, not source Git history.

## Signing and notarization

Default builds are ad-hoc signed development/test builds. They do not include a Developer ID certificate or signing keys. They are not notarized and may be blocked by Gatekeeper or a managed Mac's policies. Follow [Apple's opening instructions](https://support.apple.com/102445) where an exception is available; never recommend disabling Gatekeeper globally.

For a smoother general release, configure a Developer ID Application identity and notarize the app. Signing includes the publisher's identity. Keep all credentials in the Keychain or protected CI secrets, never source control.

```sh
REFOCUS_SIGN_IDENTITY="Developer ID Application: Publisher (TEAMID)" bash scripts/build.sh --universal
xcrun notarytool submit dist/Refocus-macOS.zip --keychain-profile RefocusNotary --wait
xcrun stapler staple dist/Refocus.app
spctl --assess --type execute --verbose dist/Refocus.app
bash scripts/package.sh --use-built-app
```

Only package the notarized app after Apple accepts the submission, stapling succeeds, and Gatekeeper assessment passes. `--use-built-app` preserves the existing app signature/ticket; it does not rebuild. The privacy audit flags email addresses and personal build paths but allows normal public Developer ID signing metadata. Test the final downloaded artifact again. See [Apple's notarization documentation](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution).

GitHub Actions checks source and creates development artifacts; it does not hold signing credentials or automatically publish a release.
