# Website aliases

Generated from [the editable catalog](Sources/RefocusCore/SiteAliases.swift).
Edit that file, then run `bash scripts/update-aliases.sh` to update this reference.

Every entry blocks itself and its `www` form. A listed entry also adds the exact
aliases below. Other subdomains stay narrow. Removing a site removes its aliases,
unless another listed entry still selects them.

See [DNS observations and shared-server limits](docs/site-aliases.md) before adding
fallback targets. Avoid shared CDN infrastructure and IP addresses.

## Discord

Add any of: `discord.com`, `discord.gg`, `discordapp.com`.

Additional aliases:

```text
discord.com
www.discord.com
discord.gg
www.discord.gg
discordapp.com
www.discordapp.com
```

## Facebook

Add any of: `facebook.com`.

Additional aliases:

```text
m.facebook.com
mbasic.facebook.com
web.facebook.com
touch.facebook.com
star-mini.c10r.facebook.com
star-mini.fallback.c10r.facebook.com
```

## Instagram

Add any of: `instagram.com`.

Additional aliases:

```text
z-p42-instagram.c10r.instagram.com
z-p42-instagram.fallback.c10r.instagram.com
z-p42-instagram.fallback.c10r.facebook.com
```

## Messenger

Add any of: `messenger.com`, `m.me`.

Additional aliases:

```text
messenger.com
www.messenger.com
m.me
www.m.me
star.facebook.com
star.c10r.facebook.com
star.fallback.c10r.facebook.com
```

## Reddit

Add any of: `reddit.com`.

Additional aliases:

```text
old.reddit.com
new.reddit.com
m.reddit.com
np.reddit.com
sh.reddit.com
reddit.map.fastly.net
```

## Snapchat

Add any of: `snapchat.com`, `web.snapchat.com`.

Additional aliases:

```text
snapchat.com
www.snapchat.com
web.snapchat.com
web-gcp.api.snapchat.com
web-gcp.api.sc-gw.com
```

## TikTok

Add any of: `tiktok.com`, `vm.tiktok.com`, `vt.tiktok.com`.

Additional aliases:

```text
tiktok.com
www.tiktok.com
m.tiktok.com
vm.tiktok.com
vt.tiktok.com
www.tiktok.com.edgesuite.net
m.tiktok.com.edgesuite.net
vm.tiktok.com.ttdns2.com
vm.tiktok.com.edgesuite.net
vt.tiktok.com.ttdns2.com
vt.tiktok.com.edgesuite.net
```

## Twitch

Add any of: `twitch.tv`.

Additional aliases:

```text
m.twitch.tv
mobile.twitch.tv
ttv-redirect.m7g.twitch.tv
h2.twitch.map.fastly.net
```

## WhatsApp

Add any of: `whatsapp.com`, `web.whatsapp.com`, `api.whatsapp.com`, `wa.me`.

Additional aliases:

```text
whatsapp.com
www.whatsapp.com
web.whatsapp.com
api.whatsapp.com
wa.me
www.wa.me
mmx-ds.cdn.whatsapp.net
```

## X / Twitter

Add any of: `x.com`, `twitter.com`.

Additional aliases:

```text
x.com
www.x.com
twitter.com
www.twitter.com
mobile.x.com
m.x.com
wr.x.com
mobile.twitter.com
m.twitter.com
s.twitter.com
```

## YouTube

Add any of: `youtube.com`, `youtu.be`.

Additional aliases:

```text
youtube.com
www.youtube.com
m.youtube.com
music.youtube.com
youtu.be
www.youtu.be
```
