# Installation and troubleshooting

## First installation

1. Open [Releases](https://github.com/Phionx/refocus/releases) and download **Refocus-VERSION-macOS.dmg** from the release's Assets. Choose the DMG, rather than GitHub's source-code ZIP.
2. Open the DMG and **drag Refocus into the Applications folder shortcut**.
3. Open **Refocus from Applications**, then eject the DMG. Its focus-frame icon appears in the menu bar; it does not stay in the Dock.
4. Click the menu-bar icon, review the initial website list, then choose **Enable blocking…**.
5. **Approve the background helper** when macOS opens System Settings. Go to **General → Login Items** (or **Login Items & Extensions**) and allow **Refocus / RefocusHelper** under **Allow in the Background**. You may need an administrator's approval.
6. Return to Refocus. It will finish enabling blocking. Your site list and the switch save immediately.

### macOS security message

The initial releases are **ad-hoc signed and not notarized**. macOS may initially prevent them from opening. After attempting to open the app, go to **System Settings → Privacy & Security → Open Anyway**, then confirm. See [Apple's instructions](https://support.apple.com/102445). Availability depends on your Mac's security policy; a managed Mac may not permit an exception. Do not disable Gatekeeper globally.

A future Developer ID-signed, notarized release will simplify this step. If the app still will not open, include the exact message and macOS version in a GitHub issue, without posting personal information. You can also [build from source](#build-from-source).

### Why allow a background helper?

macOS protects the system hosts file. Refocus uses a small privileged helper to update **only its marked website-block section** and save its settings. The interface itself does not run as root. The helper does not inspect browsing traffic, record browser history, or send your list to a server.

**Background approval is required for blocking to work.** It is separate from the optional **Open Refocus at login** setting. The helper stays available while blocking is enabled and normally exits after 60 idle seconds when disabled. **Quitting Refocus turns blocking off**, including during a pause. The helper also watches for a force quit or crash and removes the rules. Helper restarts and reboots start with blocking off.

## Everyday use

- Click the focus-frame icon in the menu bar to open Refocus.
- Add a domain or paste a URL. Refocus keeps its hostname; `www` and [known aliases](SITE_ALIASES.md) are included automatically for supported services.
- Use the switch to turn blocking on or off. **Pause 5 min** temporarily lifts it; **Resume now** restores it early.
- Remove a website with its × button. Aliases stay only if another entry still selects them.
- Choose **More options → Quit Refocus · turn blocking off** to quit and unblock. Your list stays saved; reopening starts off.
- **More options → Open Refocus at login** is optional. It opens the interface at login; it does not automatically turn blocking on.

**Fully quit and reopen your browser to apply changes immediately, or wait a bit for them to take effect.** Browsers can reuse cached DNS answers and open connections, even after a page refresh. Refocus does not close browser connections. A blocked page normally shows a connection error.

This is an impulse barrier. VPNs, proxies, private resolvers, different regional DNS targets, and native apps can bypass it. Messenger shares some fallback servers with Facebook, so blocking Messenger can affect Facebook features or integrations on other sites. The app shows a note when that applies. See [the DNS notes](docs/site-aliases.md) for scope limits.

## Updating Refocus

For **0.2.0 and later**:

1. **Quit the running Refocus** from its menu. This removes the active blocks.
2. Download the newer DMG from [Releases](https://github.com/Phionx/refocus/releases).
3. Open it, drag Refocus into Applications, and choose **Replace**. Do not keep two copies or replace a running app.
4. Open Refocus from Applications. Your website list is preserved. Refocus refreshes its helper when the version/build changes.
5. If macOS asks, approve the updated background helper in **General → Login Items** again. Turn blocking on when ready.

If helper refresh fails, use **More options → Refresh background helper**, then check its background approval. Refocus shows the failure; it does not silently claim blocking is active.

**One-time upgrade from a 0.1.x test build:** in the old app, choose **More options → Disable & remove helper**, then quit it **before** replacing it. Version 0.2.0 changes the old development app/helper identifiers. This extra removal step is for that migration; later updates use the flow above. Do not delete your saved website list.

## Uninstalling

1. Turn off **More options → Open Refocus at login**, if enabled.
2. Choose **More options → Disable & remove helper**. Wait for it to finish; approve the helper again first if its permission was revoked.
3. Quit Refocus and delete it from Applications. Local preferences can be left in place.

If the app is unavailable and rules are stranded, an administrator can edit `/etc/hosts` and remove **only** the lines from `# BEGIN REFOCUS - managed by Refocus` through `# END REFOCUS`, inclusive. Preserve everything else. Then run `sudo dscacheutil -flushcache` and `sudo killall -HUP mDNSResponder`.


## Testing status

The initial release is an early testing release. Gatekeeper, background-helper approval, and replacing an installed app still need verification on a separate Mac. Automated fixture checks do not establish those results.
