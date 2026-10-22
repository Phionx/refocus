import Foundation
import Darwin
import RefocusCore

var passed = 0
var failed = 0
func test(_ name: String, _ check: () throws -> Void) {
    do { try check(); passed += 1; print("PASS \(name)") }
    catch { failed += 1; print("FAIL \(name): \(error)") }
}
func expect(_ condition: @autoclosure () throws -> Bool, _ message: String = "Unexpected result") throws {
    if try !condition() { throw RefocusError.invalid(message) }
}
func rejects(_ action: () throws -> Void) throws {
    do { try action() } catch { return }
    throw RefocusError.invalid("Expected rejection")
}

let now = Date(timeIntervalSince1970: 1_800_000_000)
let original = "# Keep this comment\n127.0.0.1 localhost\n::1 localhost\n192.168.1.3 workstation.local\n"
let on = Configuration(sites: ["reddit.com"], enabled: true)

test("Normalize pasted URLs and www") { try expect(Site.normalize("  HTTPS://WWW.Reddit.com/r/swift?q=1  ") == "reddit.com") }
test("Normalize a trailing DNS dot") { try expect(Site.normalize("example.com.") == "example.com") }
test("Reject hosts-file injection") { try rejects { _ = try Site.normalize("reddit.com\n127.0.0.1 bank.com") } }
test("Reject credentials and non-web schemes") {
    for input in ["https://a:b@example.com", "file:///etc/hosts", "ftp://example.com"] { try rejects { _ = try Site.normalize(input) } }
}
test("Reject invalid and local hostnames") {
    for input in ["localhost", "127.0.0.1", "[::1]", "a..com", "-a.com", "a-.com", "a_b.com", "a.local", "a.invalid", "a.test", ""] {
        try rejects { _ = try Site.normalize(input) }
    }
}
test("Reject overlong labels") { try rejects { _ = try Site.normalize(String(repeating: "a", count: 64) + ".com") } }
test("Retain an explicitly entered subdomain") { try expect(Site.normalize("old.reddit.com") == "old.reddit.com") }
test("Deduplicate normalized sites") {
    let config = try Configuration(sites: ["REDDIT.COM", "www.reddit.com", "x.com"]).validated(at: now)
    try expect(config.sites == ["reddit.com", "x.com"])
}
test("Bound configuration size") { try rejects { _ = try Configuration(sites: Array(repeating: "x.com", count: 501)).validated(at: now) } }
test("Include explicit common aliases") {
    try expect(on.hostnames.contains("old.reddit.com"))
    try expect(Site.hostnames(for: "x.com").contains("twitter.com"))
    try expect(Site.hostnames(for: "example.com") == ["example.com", "www.example.com"])
}
test("Facebook rules cover www canonical and HTTPS fallback targets") {
    let config = try Configuration(sites: ["https://www.facebook.com"], enabled: true).validated(at: now)
    try expect(config.sites == ["facebook.com"])
    let result = try HostsFile.rendering(original, configuration: config, at: now)
    for host in ["facebook.com", "www.facebook.com", "star-mini.c10r.facebook.com", "star-mini.fallback.c10r.facebook.com"] {
        try expect(result.contains("0.0.0.0 \(host)\n:: \(host)\n"), "Missing Facebook target: \(host)")
    }
}
test("Instagram covers both apex and www HTTPS backup targets") {
    let result = try HostsFile.rendering(original, configuration: Configuration(sites: ["instagram.com"], enabled: true), at: now)
    for host in ["z-p42-instagram.c10r.instagram.com", "z-p42-instagram.fallback.c10r.instagram.com", "z-p42-instagram.fallback.c10r.facebook.com"] {
        try expect(result.contains("0.0.0.0 \(host)\n:: \(host)\n"), "Missing Instagram target: \(host)")
    }
}
test("Messenger covers its canonical chain and HTTPS fallback") {
    let hosts = Site.hostnames(for: "messenger.com")
    try expect(Set(["m.me", "star.facebook.com", "star.c10r.facebook.com", "star.fallback.c10r.facebook.com"]).isSubset(of: hosts))
    try expect(Site.hostnames(for: "m.me").contains("www.messenger.com"))
}
test("WhatsApp web and short links include the website's canonical target") {
    for entry in ["whatsapp.com", "web.whatsapp.com", "api.whatsapp.com", "wa.me"] {
        let hosts = Site.hostnames(for: entry)
        try expect(Set(["web.whatsapp.com", "api.whatsapp.com", "mmx-ds.cdn.whatsapp.net"]).isSubset(of: hosts))
    }
}
test("X and Twitter cover their mobile CNAME targets") {
    for entry in ["x.com", "twitter.com"] {
        try expect(Set(["m.x.com", "mobile.x.com", "wr.x.com", "m.twitter.com", "s.twitter.com"]).isSubset(of: Site.hostnames(for: entry)))
    }
}
test("Additional service presets cover observed service-specific targets") {
    let cases = [
        "reddit.com": "reddit.map.fastly.net", "tiktok.com": "www.tiktok.com.edgesuite.net",
        "twitch.tv": "h2.twitch.map.fastly.net", "snapchat.com": "web-gcp.api.sc-gw.com",
        "discord.gg": "discord.com", "youtu.be": "www.youtube.com"
    ]
    for (entry, target) in cases { try expect(Site.hostnames(for: entry).contains(target), "Missing target for \(entry)") }
}
test("Presets stay conditional and avoid broad or shared CDN blocks") {
    let instagram = Site.hostnames(for: "instagram.com")
    try expect(!instagram.contains("facebook.com") && !instagram.contains("messenger.com") && !instagram.contains("whatsapp.com"))
    try expect(!instagram.contains("star.fallback.c10r.instagram.com")) // Also used by Threads.
    let hosts = Configuration(sites: ["reddit.com", "tiktok.com", "twitch.tv", "snapchat.com", "instagram.com"]).hostnames
    for excluded in ["fastly.net", "facebook.com", "cloudfront.net", "akamai.net", "shared-global-api-spread.bytewlb.akadns.net", "a2047.api1.akamai.net"] {
        try expect(!hosts.contains(excluded), "Overly broad target: \(excluded)")
    }
    try expect(Site.hostnames(for: "old.reddit.com") == ["old.reddit.com", "www.old.reddit.com"])
}
test("Removing a site drops its backup rules while retaining other selected sites") {
    let first = try HostsFile.rendering(original, configuration: Configuration(sites: ["instagram.com", "whatsapp.com"], enabled: true), at: now)
    let next = try HostsFile.rendering(first, configuration: Configuration(sites: ["whatsapp.com"], enabled: true), at: now)
    try expect(!next.contains("instagram"))
    try expect(next.contains("mmx-ds.cdn.whatsapp.net"))
    try expect(HostsFile.rendering(next, configuration: Configuration(enabled: false), at: now) == original)
}
test("Catalog entries are unambiguous and aliases are valid hostnames") {
    var entries = Set<String>()
    for preset in SiteAliases.presets {
        try expect(!preset.name.isEmpty && !preset.entries.isEmpty)
        try expect(preset.aliases.count == Set(preset.aliases).count)
        for entry in preset.entries {
            try expect(Site.normalize(entry) == entry)
            try expect(entries.insert(entry).inserted, "Ambiguous preset entry: \(entry)")
        }
        for host in preset.aliases {
            let normalized = try Site.normalize(host)
            try expect(host == normalized || host == "www." + normalized, "Invalid alias: \(host)")
        }
    }
}
test("An alias remains until all of its selected entry points are removed") {
    let first = try HostsFile.rendering(original, configuration: Configuration(sites: ["whatsapp.com", "wa.me"], enabled: true), at: now)
    let next = try HostsFile.rendering(first, configuration: Configuration(sites: ["wa.me"], enabled: true), at: now)
    try expect(next.contains("mmx-ds.cdn.whatsapp.net"))
    try expect(HostsFile.rendering(next, configuration: Configuration(sites: [], enabled: true), at: now) == original)
}
test("Write both address families") {
    let result = try HostsFile.rendering(original, configuration: on, at: now)
    try expect(result.contains("0.0.0.0 reddit.com\n:: reddit.com"))
    try expect(!result.contains("*"))
}
test("Preserve all unrelated hosts content") {
    let result = try HostsFile.rendering(original, configuration: on, at: now)
    try expect(result.hasPrefix(original))
    try expect(HostsFile.removingRules(from: result) == original)
}
test("Updates are idempotent") {
    let first = try HostsFile.rendering(original, configuration: on, at: now)
    try expect(HostsFile.rendering(first, configuration: on, at: now) == first)
}
test("Remove obsolete Refocus rules when the list changes") {
    let first = try HostsFile.rendering(original, configuration: on, at: now)
    let next = try HostsFile.rendering(first, configuration: Configuration(sites: ["x.com"], enabled: true), at: now)
    try expect(!next.contains("reddit.com")); try expect(next.contains("twitter.com"))
}
test("Disable removes only Refocus's block") {
    let first = try HostsFile.rendering(original, configuration: on, at: now)
    try expect(HostsFile.rendering(first, configuration: Configuration(enabled: false), at: now) == original)
}
test("Keep later edits made by other programs") {
    let first = try HostsFile.rendering(original, configuration: on, at: now) + "10.0.0.2 custom.example\n"
    try expect(HostsFile.removingRules(from: first) == original + "10.0.0.2 custom.example\n")
}
test("Handle an original with no final newline") {
    let result = try HostsFile.rendering("127.0.0.1 localhost", configuration: on, at: now)
    try expect(result.hasPrefix("127.0.0.1 localhost\n"))
    try expect(HostsFile.rendering(result, configuration: on, at: now) == result)
}
test("Refuse incomplete, reversed or duplicate owned blocks") {
    for broken in [HostsFile.begin + "\nx", HostsFile.end + "\n", HostsFile.end + "\n" + HostsFile.begin, HostsFile.begin + "\n" + HostsFile.begin + "\n" + HostsFile.end, HostsFile.begin + "\n" + HostsFile.end + "\n" + HostsFile.begin + "\n" + HostsFile.end] {
        try rejects { _ = try HostsFile.rendering(broken, configuration: on, at: now) }
    }
}
test("A pause removes rules until its deadline") {
    let paused = Configuration(sites: ["reddit.com"], enabled: true, pausedUntil: now.addingTimeInterval(300))
    let first = try HostsFile.rendering(original, configuration: on, at: now)
    try expect(HostsFile.rendering(first, configuration: paused, at: now) == original)
    try expect(HostsFile.rendering(original, configuration: paused, at: now.addingTimeInterval(301)).contains(HostsFile.begin))
}
test("Expire stale pause state") {
    let config = try Configuration(enabled: true, pausedUntil: now.addingTimeInterval(-5)).validated(at: now)
    try expect(config.pausedUntil == nil)
    try expect(config.isBlocking(at: now))
}
test("Disable clears pauses") {
    let config = try Configuration(enabled: false, pausedUntil: now.addingTimeInterval(300)).validated(at: now)
    try expect(config.pausedUntil == nil)
}
test("Reject indefinite and excessively long pauses") {
    try rejects { _ = try Configuration(enabled: true, pausedUntil: now.addingTimeInterval(90000)).validated(at: now) }
}
test("Round-trip persisted pause and site settings") {
    let config = Configuration(enabled: true, pausedUntil: now.addingTimeInterval(300))
    try expect(RefocusJSON.decode(Configuration.self, from: RefocusJSON.encode(config)) == config)
}
test("Empty lists leave unrelated networking alone") {
    try expect(HostsFile.rendering(original, configuration: Configuration(sites: [], enabled: true), at: now) == original)
}

let temporary = FileManager.default.temporaryDirectory.appendingPathComponent("refocus-checks-" + UUID().uuidString)
try FileManager.default.createDirectory(at: temporary, withIntermediateDirectories: true)
defer { try? FileManager.default.removeItem(at: temporary) }
let fixture = temporary.appendingPathComponent("hosts")
test("Atomic update of a real fixture preserves permissions") {
    try Data(original.utf8).write(to: fixture)
    try FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: fixture.path)
    let store = HostsStore(url: fixture, owner: getuid())
    try expect(store.apply(on, at: now))
    try expect(!store.apply(on, at: now))
    let permissions = try FileManager.default.attributesOfItem(atPath: fixture.path)[.posixPermissions] as! NSNumber
    try expect(permissions.intValue == 0o644)
    try expect(store.apply(Configuration(enabled: false), at: now))
    try expect(String(contentsOf: fixture) == original)
}
test("Refuse a symlink hosts target") {
    let link = temporary.appendingPathComponent("linked-hosts")
    try FileManager.default.createSymbolicLink(at: link, withDestinationURL: fixture)
    try rejects { _ = try HostsStore(url: link, owner: getuid()).apply(on, at: now) }
    try expect(String(contentsOf: fixture) == original)
}
test("Refuse an unexpected hosts owner") {
    try rejects { _ = try HostsStore(url: fixture, owner: getuid() + 1).apply(on, at: now) }
}
test("Refuse a writable-by-others hosts file") {
    try FileManager.default.setAttributes([.posixPermissions: 0o666], ofItemAtPath: fixture.path)
    try rejects { _ = try HostsStore(url: fixture, owner: getuid()).apply(on, at: now) }
    try FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: fixture.path)
}

// Exercise the actual helper engine with disposable hosts/settings and real process exits.
func fixtureEngine() throws -> (BlockingEngine, URL, URL) {
    let directory = temporary.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let file = directory.appendingPathComponent("hosts")
    try Data(original.utf8).write(to: file)
    try FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: file.path)
    let settings = directory.appendingPathComponent("settings")
    return (BlockingEngine(directory: settings, fileOwner: getuid(), fileGroup: getgid(),
                           hosts: HostsStore(url: file, owner: getuid())), file, settings)
}
func childProcess() throws -> Process {
    let child = Process(); child.executableURL = URL(fileURLWithPath: "/bin/sleep"); child.arguments = ["30"]
    try child.run(); return child
}
func endChild(_ child: Process) {
    if child.isRunning { kill(child.processIdentifier, SIGKILL) }
    child.waitUntilExit()
}
func eventually(_ check: () throws -> Bool) throws {
    let deadline = Date().addingTimeInterval(4)
    repeat {
        if try check() { return }
        Thread.sleep(forTimeInterval: 0.02)
    } while Date() < deadline
    throw RefocusError.invalid("Timed out waiting for process-exit cleanup")
}

test("Quit disables blocking, clears a pause and preserves the latest list") {
    let (engine, file, _) = try fixtureEngine()
    try engine.queue.sync {
        _ = try engine.apply(on, for: getuid(), process: getpid())
        _ = try engine.apply(Configuration(sites: ["instagram.com", "whatsapp.com"], enabled: true,
                                           pausedUntil: Date().addingTimeInterval(30)), for: getuid(), process: getpid())
        let off = try engine.stop(for: getuid())!
        try expect(!off.enabled && off.pausedUntil == nil)
        try expect(off.sites == ["instagram.com", "whatsapp.com"])
        try expect(String(contentsOf: file) == original)
        try expect(engine.read(for: getuid()) == off)
    }
}
test("A force-killed app removes active rules and saves blocking off") {
    let (engine, file, _) = try fixtureEngine()
    let child = try childProcess(); defer { endChild(child) }
    try engine.queue.sync { _ = try engine.apply(on, for: getuid(), process: child.processIdentifier) }
    try expect(String(contentsOf: file).contains(HostsFile.begin))
    endChild(child)
    try eventually { try engine.queue.sync { try engine.read(for: getuid())?.enabled == false } }
    try expect(String(contentsOf: file) == original)
}
test("Exiting during a pause cannot resume blocking later") {
    let (engine, file, _) = try fixtureEngine()
    let child = try childProcess(); defer { endChild(child) }
    let config = Configuration(sites: ["instagram.com"], enabled: true, pausedUntil: Date().addingTimeInterval(2))
    try engine.queue.sync { _ = try engine.apply(config, for: getuid(), process: child.processIdentifier) }
    endChild(child)
    try eventually { try engine.queue.sync { try engine.read(for: getuid())?.enabled == false } }
    try engine.queue.sync {
        let saved = try engine.read(for: getuid())!
        try expect(saved.pausedUntil == nil)
        try engine.reconcile()
    }
    try expect(String(contentsOf: file) == original)
}
test("A helper restart clears rules and never restores saved blocking automatically") {
    let (oldEngine, file, settings) = try fixtureEngine()
    try oldEngine.queue.sync { _ = try oldEngine.apply(on, for: getuid(), process: getpid()) }
    let restarted = BlockingEngine(directory: settings, fileOwner: getuid(), fileGroup: getgid(), hosts: HostsStore(url: file, owner: getuid()))
    try restarted.queue.sync {
        try restarted.resetAfterRestart()
        let saved = try restarted.read(for: getuid())!
        try expect(!saved.enabled && saved.pausedUntil == nil && saved.sites == on.sites)
    }
    try expect(String(contentsOf: file) == original)
}
test("Startup removes orphaned rules even without readable saved settings") {
    let (engine, file, settings) = try fixtureEngine()
    _ = try HostsStore(url: file, owner: getuid()).apply(on)
    try engine.queue.sync { try engine.resetAfterRestart() }
    try expect(String(contentsOf: file) == original)
    try Data("broken".utf8).write(to: settings.appendingPathComponent("state.json"))
    try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: settings.appendingPathComponent("state.json").path)
    _ = try HostsStore(url: file, owner: getuid()).apply(on)
    try engine.queue.sync { try rejects { try engine.resetAfterRestart() } }
    try expect(String(contentsOf: file) == original)
}
test("Blocking cannot be enabled for an app process that has already exited") {
    let (engine, file, _) = try fixtureEngine()
    let child = try childProcess(); let pid = child.processIdentifier; endChild(child)
    try engine.queue.sync {
        try rejects { _ = try engine.apply(on, for: getuid(), process: pid) }
        try rejects { _ = try engine.apply(on, for: getuid(), process: 0) }
    }
    try expect(String(contentsOf: file) == original)
}
test("Rapid exit during process notification registration is cleaned up") {
    for _ in 0..<5 {
        let (engine, file, _) = try fixtureEngine()
        let child = try childProcess(); defer { endChild(child) }
        try engine.queue.sync {
            _ = try engine.apply(on, for: getuid(), process: child.processIdentifier)
            endChild(child)
        }
        try eventually { try engine.queue.sync { try engine.read(for: getuid())?.enabled == false } }
        try expect(String(contentsOf: file) == original)
    }
}
test("A previous app session cannot disable a newer active session") {
    let (engine, file, _) = try fixtureEngine()
    let first = try childProcess(); defer { endChild(first) }
    let second = try childProcess(); defer { endChild(second) }
    try engine.queue.sync {
        _ = try engine.apply(on, for: getuid(), process: first.processIdentifier)
        _ = try engine.apply(Configuration(sites: ["instagram.com"], enabled: true), for: getuid(), process: second.processIdentifier)
        endChild(first)
    }
    try engine.queue.sync { try expect(engine.read(for: getuid())?.enabled == true) }
    try expect(String(contentsOf: file).contains("instagram.com"))
    endChild(second)
    try eventually { try engine.queue.sync { try engine.read(for: getuid())?.enabled == false } }
    try expect(String(contentsOf: file) == original)
}
test("The pause still resumes while its app is alive") {
    let (engine, file, _) = try fixtureEngine()
    let config = Configuration(sites: ["reddit.com"], enabled: true, pausedUntil: Date().addingTimeInterval(1.2))
    try engine.queue.sync { _ = try engine.apply(config, for: getuid(), process: getpid()) }
    try expect(String(contentsOf: file) == original)
    try eventually { try String(contentsOf: file).contains(HostsFile.begin) }
    try engine.queue.sync { _ = try engine.stop(for: getuid()) }
    try expect(String(contentsOf: file) == original)
}
test("Another account cannot stop an active session") {
    let (engine, file, _) = try fixtureEngine()
    try engine.queue.sync {
        _ = try engine.apply(on, for: getuid(), process: getpid())
        try rejects { _ = try engine.stop(for: getuid() + 1) }
        try expect(engine.read(for: getuid())?.enabled == true)
        _ = try engine.stop(for: getuid())
    }
    try expect(String(contentsOf: file) == original)
}

print("\n\(passed) passed; \(failed) failed. System hosts file was never modified.")
exit(failed == 0 ? EXIT_SUCCESS : EXIT_FAILURE)
