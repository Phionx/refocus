# DNS observations and alias scope

For the complete readable mapping, see [SITE_ALIASES.md](../SITE_ALIASES.md). To edit it, change [the catalog](../Sources/RefocusCore/SiteAliases.swift) and run `bash scripts/update-aliases.sh`.

Presets expand selected sites into exact hosts entries. They do not resolve DNS at runtime, block IP ranges, install extensions, or add unselected service presets. Every generated host is written for both IPv4 and IPv6 and disappears when its last selecting entry is removed, blocking is disabled, or Refocus exits.

## DNS observations

Checked on 2026-10-21 using macOS `dig` against the system's recursive resolver. DNS varies by region and can change; these are verified examples, not exhaustive lists. HTTPS records (type 65) can provide a fallback hostname even when there is no CNAME. Priority 1 targets of `.` mean the queried name itself and require no extra rule.

| Selected service | Observed canonical / HTTPS targets included |
| --- | --- |
| Facebook | `www.facebook.com` and `m.facebook.com` → `star-mini.c10r.facebook.com`; apex and canonical HTTPS fallback → `star-mini.fallback.c10r.facebook.com` |
| Instagram | `www.instagram.com` → `z-p42-instagram.c10r.instagram.com` → HTTPS fallback `z-p42-instagram.fallback.c10r.instagram.com`; apex HTTPS fallback → `z-p42-instagram.fallback.c10r.facebook.com` |
| Messenger | `www.messenger.com` → `star.facebook.com` → `star.c10r.facebook.com`; apex, `m.me`, and canonical HTTPS fallback → `star.fallback.c10r.facebook.com` |
| WhatsApp | `www.whatsapp.com` and `web.whatsapp.com` → `mmx-ds.cdn.whatsapp.net`; `api.whatsapp.com` → `web.whatsapp.com` |
| X / Twitter | `www.x.com` → `x.com`; `www.twitter.com` → `twitter.com`; `m.x.com` → `wr.x.com`; `m.twitter.com` → `s.twitter.com` |
| Reddit | `www.reddit.com` and `old.reddit.com` → `reddit.map.fastly.net` |
| TikTok | Website, mobile, and short-link CNAMEs under `tiktok.com.edgesuite.net` and `tiktok.com.ttdns2.com` (exact hosts in `Site.hostnames`) |
| Twitch | `www.twitch.tv` → `h2.twitch.map.fastly.net`; `mobile.twitch.tv` → `ttv-redirect.m7g.twitch.tv` |
| Snapchat | `www.snapchat.com` and `web.snapchat.com` → `web-gcp.api.snapchat.com` → `web-gcp.api.sc-gw.com` |
| YouTube / Discord | No additional named HTTPS fallback observed; common public domains and short links are included |

To recheck a service, use e.g.:

```sh
dig +noall +answer www.instagram.com CNAME instagram.com TYPE65 www.instagram.com TYPE65
```

Older `dig` versions print HTTPS records as type 65 hexadecimal wire data. The first two bytes are priority, followed by the DNS-encoded target name and service parameters. Follow service-specific CNAMEs and HTTPS target names, rather than copying address records.

## Shared targets and limits

- Messenger uses the exact `star.*.facebook.com` names also used by `web.facebook.com`, `mbasic.facebook.com`, and `graph.facebook.com`. Including those targets is necessary to cover the observed Messenger fallback path and can affect Facebook features, including integrations on other sites. The UI warns when Messenger is selected without Facebook. It does not add the Facebook homepage's `star-mini` targets or the Instagram or WhatsApp presets.
- Facebook's `web`, `mbasic`, and `touch` aliases are included, but their shared `star` DNS targets are added only when Messenger is selected. This keeps a Facebook entry from automatically selecting Messenger's server targets.
- `i.instagram.com` uses `instagram.c10r.instagram.com` with HTTPS fallback `star.fallback.c10r.instagram.com`. Threads uses that same fallback. These API targets are omitted from the Instagram website preset to avoid adding a shared Instagram/Threads block. The public Instagram website's `z-p42-instagram` targets are included.
- TikTok's final shared Akamai targets (`shared-global-api-spread.bytewlb.akadns.net`, `a2047.api1.akamai.net`, and regional `a*.r.akamai.net`) are omitted. Twitch's opaque CloudFront distribution target is omitted. Exact service-named Fastly/EdgeSuite hosts are included; CDN parent domains and IP addresses are never blocked.
- These presets cover browser entry points. Native apps, different regional DNS targets, cached connections, proxies, or independent DNS resolvers may still work. No background DNS discovery or network interception is performed.

## Entry points that select a preset

Ordinary `www` prefixes are normalized first. Presets are selected by these explicit entries:

- `facebook.com`, `instagram.com`, `reddit.com`, `twitch.tv` (each selects its own service).
- `messenger.com` or `m.me`.
- `x.com` or `twitter.com`.
- `whatsapp.com`, `web.whatsapp.com`, `api.whatsapp.com`, or `wa.me`.
- `youtube.com` or `youtu.be`.
- `tiktok.com`, `vm.tiktok.com`, or `vt.tiktok.com`.
- `discord.com`, `discord.gg`, or `discordapp.com`.
- `snapchat.com` or `web.snapchat.com`.

Other explicitly entered subdomains stay narrow. For example, `old.reddit.com` does not select all of Reddit, and `music.youtube.com` does not select all of YouTube. A shared alias stays present until all entries that select it have been removed.
