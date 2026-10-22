# Contributing to Refocus

Keep Refocus a small first line of defense against habitual website visits. Avoid remote services, continuous traffic inspection, shared-IP blocking, and browser-wide resets.

## Workflow

1. Fork the repo and make a focused branch.
2. On macOS 13+ with Command Line Tools, run `bash scripts/test.sh` and `bash scripts/build.sh`.
3. Test the resulting app from Applications when your change affects the interface or helper. Approve the background helper in System Settings. Quit Refocus before replacing an installed 0.2.0+ build.
4. Open a pull request with the problem, resulting behavior, and relevant checks. Do not upload personal settings, certificates, credentials, local paths, or built app bundles in source commits.

A full Xcode installation is optional. No third-party Swift packages are needed. `bash scripts/package.sh` produces universal versioned downloads. Generated output belongs in the ignored `.build/` and `dist/` folders.

## Adding website aliases

The single editable catalog is **[Sources/RefocusCore/SiteAliases.swift](Sources/RefocusCore/SiteAliases.swift)**. Each data record has:

- `name`: readable service name.
- `entries`: normalized domains that select this service's preset.
- `aliases`: exact additional hostnames to block. Each user-entered domain already includes itself and its `www` form.

Add to that array; no changes to lookup logic are needed. Verify CNAME and HTTPS-record targets using public DNS, and record evidence and shared-server limits in [docs/site-aliases.md](docs/site-aliases.md). Do not add broad CDN domains, shared server targets, or IP addresses without understanding and documenting the effect on unrelated sites.

Then run:

```sh
bash scripts/update-aliases.sh
bash scripts/test.sh
bash scripts/build.sh
```

Commit both the catalog and regenerated [SITE_ALIASES.md](SITE_ALIASES.md). Tests check that the reference stays in sync, all catalog hostnames are valid, and entry points are unambiguous. Add a meaningful regression check for the DNS path or scope issue your change fixes.

## Helper and enforcement changes

Keep the XPC interface limited to validated configuration and lifecycle operations, never paths or arbitrary commands. Preserve unrelated hosts entries, existing ownership and permissions, atomic writes, and signature checks. Blocking must stop on quit, force quit, or helper restart. A pause may resume only while its app is alive.

Checks run the production engine on temporary files and child processes, never the system hosts file. Test real Service Management setup separately on a disposable Mac/account when appropriate. Report macOS version, CPU architecture, and exact errors; redact personal data.

## Versions and releases

Follow [docs/releasing.md](docs/releasing.md). Ordinary contributions should leave VERSION and BUILD_NUMBER unchanged unless the change is a release. Update the changelog when the change is user-visible. Contributions are under the project's MIT license.
