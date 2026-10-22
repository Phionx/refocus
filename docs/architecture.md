# Privacy and architecture

## Privacy and implementation

Refocus has no telemetry or network service. Your website list is stored locally:

- UI cache: `~/Library/Application Support/Refocus/configuration.json`.
- Helper settings: `/Library/Application Support/Refocus/state.json`, readable only by root.
- Blocking rules: a marked section in `/private/etc/hosts`, mapping explicit hostnames to `0.0.0.0` and `::`.

The app talks to its helper over authenticated XPC registered through `SMAppService`. It checks signatures, validates input again in the helper, binds settings to the initiating Mac account, preserves unrelated hosts entries, and replaces files atomically with their existing permissions. No wildcard or shared-IP blocking is used.

Builds include code, fixed defaults, icons, and documentation; **they do not bundle the developer's saved sites, hosts file, account settings, credentials, or signing keys**. Packaging scans for personal build paths, email addresses, unwanted files, and file metadata. These checks cover the published payload, not information already public on a GitHub profile. Future Developer ID signatures will identify the publisher as part of normal code signing.
