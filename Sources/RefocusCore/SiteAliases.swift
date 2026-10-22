// Single source of truth for website presets. Add a record or edit its aliases here,
// then run: bash scripts/update-aliases.sh
// DNS observations and shared-server limits live in docs/site-aliases.md.

public struct SiteAliasPreset {
    public let name: String
    public let entries: [String]
    public let aliases: [String]
}

public enum SiteAliases {
    public static let presets: [SiteAliasPreset] = [
        SiteAliasPreset(
            name: "Discord",
            entries: ["discord.com", "discord.gg", "discordapp.com"],
            aliases: [
                "discord.com",
                "www.discord.com",
                "discord.gg",
                "www.discord.gg",
                "discordapp.com",
                "www.discordapp.com",
            ]
        ),
        SiteAliasPreset(
            name: "Facebook",
            entries: ["facebook.com"],
            aliases: [
                "m.facebook.com",
                "mbasic.facebook.com",
                "web.facebook.com",
                "touch.facebook.com",
                "star-mini.c10r.facebook.com",
                "star-mini.fallback.c10r.facebook.com",
            ]
        ),
        SiteAliasPreset(
            name: "Instagram",
            entries: ["instagram.com"],
            aliases: [
                "z-p42-instagram.c10r.instagram.com",
                "z-p42-instagram.fallback.c10r.instagram.com",
                "z-p42-instagram.fallback.c10r.facebook.com",
            ]
        ),
        SiteAliasPreset(
            name: "Messenger",
            entries: ["messenger.com", "m.me"],
            aliases: [
                "messenger.com",
                "www.messenger.com",
                "m.me",
                "www.m.me",
                "star.facebook.com",
                "star.c10r.facebook.com",
                "star.fallback.c10r.facebook.com",
            ]
        ),
        SiteAliasPreset(
            name: "Reddit",
            entries: ["reddit.com"],
            aliases: [
                "old.reddit.com",
                "new.reddit.com",
                "m.reddit.com",
                "np.reddit.com",
                "sh.reddit.com",
                "reddit.map.fastly.net",
            ]
        ),
        SiteAliasPreset(
            name: "Snapchat",
            entries: ["snapchat.com", "web.snapchat.com"],
            aliases: [
                "snapchat.com",
                "www.snapchat.com",
                "web.snapchat.com",
                "web-gcp.api.snapchat.com",
                "web-gcp.api.sc-gw.com",
            ]
        ),
        SiteAliasPreset(
            name: "TikTok",
            entries: ["tiktok.com", "vm.tiktok.com", "vt.tiktok.com"],
            aliases: [
                "tiktok.com",
                "www.tiktok.com",
                "m.tiktok.com",
                "vm.tiktok.com",
                "vt.tiktok.com",
                "www.tiktok.com.edgesuite.net",
                "m.tiktok.com.edgesuite.net",
                "vm.tiktok.com.ttdns2.com",
                "vm.tiktok.com.edgesuite.net",
                "vt.tiktok.com.ttdns2.com",
                "vt.tiktok.com.edgesuite.net",
            ]
        ),
        SiteAliasPreset(
            name: "Twitch",
            entries: ["twitch.tv"],
            aliases: [
                "m.twitch.tv",
                "mobile.twitch.tv",
                "ttv-redirect.m7g.twitch.tv",
                "h2.twitch.map.fastly.net",
            ]
        ),
        SiteAliasPreset(
            name: "WhatsApp",
            entries: ["whatsapp.com", "web.whatsapp.com", "api.whatsapp.com", "wa.me"],
            aliases: [
                "whatsapp.com",
                "www.whatsapp.com",
                "web.whatsapp.com",
                "api.whatsapp.com",
                "wa.me",
                "www.wa.me",
                "mmx-ds.cdn.whatsapp.net",
            ]
        ),
        SiteAliasPreset(
            name: "X / Twitter",
            entries: ["x.com", "twitter.com"],
            aliases: [
                "x.com",
                "www.x.com",
                "twitter.com",
                "www.twitter.com",
                "mobile.x.com",
                "m.x.com",
                "wr.x.com",
                "mobile.twitter.com",
                "m.twitter.com",
                "s.twitter.com",
            ]
        ),
        SiteAliasPreset(
            name: "YouTube",
            entries: ["youtube.com", "youtu.be"],
            aliases: [
                "youtube.com",
                "www.youtube.com",
                "m.youtube.com",
                "music.youtube.com",
                "youtu.be",
                "www.youtu.be",
            ]
        ),
    ]
}
