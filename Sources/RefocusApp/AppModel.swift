import AppKit
import Combine
import ServiceManagement
import RefocusCore

@MainActor final class AppModel: ObservableObject {
    @Published private(set) var configuration = Configuration()
    @Published private(set) var helperStatus = SMAppService.Status.notRegistered
    @Published private(set) var busy = false
    @Published private(set) var helperNeedsRepair = false
    @Published var error: String?
    @Published private(set) var openAtLogin = false
    private let helper = SMAppService.daemon(plistName: RefocusService.plist)
    private let defaults = UserDefaults.standard
    private var observers: [NSObjectProtocol] = []
    private var pauseWakeup: DispatchWorkItem?
    private var quitting = false
    private var attemptedHelperRefresh = false
    private var helperBuild: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "unknown"
        return version + ":" + build
    }
    private var cache: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Refocus/configuration.json")
    }
    var helperReady: Bool { helperStatus == .enabled && !helperNeedsRepair }
    var isPaused: Bool { configuration.enabled && (configuration.pausedUntil.map { $0 > Date() } ?? false) }
    var isBlocking: Bool { configuration.isBlocking() && !configuration.sites.isEmpty }
    var statusTitle: String {
        if !helperReady { return helperStatus == .requiresApproval ? "Approval needed" : "Ready when you are" }
        if isPaused { return "Blocking is paused" }
        if configuration.enabled && configuration.sites.isEmpty { return "Add a site to get started" }
        return isBlocking ? "Blocking is on" : "Blocking is off"
    }

    init() {
        if FileManager.default.fileExists(atPath: cache.path) {
            do {
                configuration = try RefocusJSON.decode(Configuration.self, from: Data(contentsOf: cache)).validated()
            } catch { self.error = "Your local settings couldn't be read. The helper will restore its saved list when available." }
        }
        // A new app session starts off, even if its previous cache survived a crash.
        configuration.enabled = false; configuration.pausedUntil = nil
        defaults.removeObject(forKey: "EnableAfterApproval")
        helperStatus = helper.status
        openAtLogin = SMAppService.mainApp.status == .enabled
        for name in [NSApplication.didBecomeActiveNotification, NSApplication.willBecomeActiveNotification] {
            observers.append(NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor [weak self] in self?.refresh() }
            })
        }
        observers.append(NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor [weak self] in self?.refresh() }
        })
    }

    func refresh() {
        guard !busy, !quitting else { return }
        helperStatus = helper.status
        openAtLogin = SMAppService.mainApp.status == .enabled
        guard helperReady else { return }
        if defaults.string(forKey: "RegisteredHelperBuild") != helperBuild {
            if !attemptedHelperRefresh { refreshHelper() }
            return
        }
        busy = true
        Task {
            defer { busy = false }
            do {
                if defaults.bool(forKey: "EnableAfterApproval") {
                    var desired = configuration; desired.enabled = true; desired.pausedUntil = nil
                    configuration = try await HelperClient.request(desired) ?? desired
                    defaults.removeObject(forKey: "EnableAfterApproval")
                } else if let saved = try await HelperClient.request() { configuration = saved }
                try saveCache(); schedulePauseRefresh(); error = nil
            } catch { self.error = error.localizedDescription; helperStatus = helper.status }
        }
    }

    func setUp() {
        guard !busy, !quitting else { return }
        error = nil
        defaults.set(true, forKey: "EnableAfterApproval")
        do {
            if helper.status == .notRegistered || helper.status == .notFound { try helper.register() }
            helperStatus = helper.status
            defaults.set(helperBuild, forKey: "RegisteredHelperBuild")
            if helperStatus == .requiresApproval { SMAppService.openSystemSettingsLoginItems() }
            else { refresh() }
        } catch {
            helperStatus = helper.status
            // register() can throw while successfully adding an item that awaits approval.
            if helperStatus == .requiresApproval {
                defaults.set(helperBuild, forKey: "RegisteredHelperBuild")
                SMAppService.openSystemSettingsLoginItems()
            } else {
                defaults.removeObject(forKey: "EnableAfterApproval")
                self.error = "Couldn't set up blocking: \(error.localizedDescription)"
            }
        }
    }

    func refreshHelper() {
        guard !busy, !quitting else { return }
        attemptedHelperRefresh = true
        busy = true; error = nil
        Task {
            defer { busy = false }
            do {
                // Quit-before-replace clears the old rules. The replacement helper also
                // starts off and removes any orphaned rules before serving requests.
                if try hasSystemRules() {
                    // Manual refresh must remove active rules before stopping the helper.
                    _ = try await HelperClient.stopBlocking()
                    guard try !hasSystemRules() else {
                        throw RefocusError.invalid("Quit the previous version and remove its helper before updating.")
                    }
                }
                if helper.status == .enabled || helper.status == .requiresApproval {
                    try await helper.unregister()
                }
                do { try helper.register() }
                catch { if helper.status != .requiresApproval { throw error } }
                helperStatus = helper.status
                guard helperStatus == .enabled || helperStatus == .requiresApproval else {
                    throw RefocusError.invalid("The background helper couldn't be registered.")
                }
                defaults.set(helperBuild, forKey: "RegisteredHelperBuild")
                defaults.removeObject(forKey: "EnableAfterApproval")
                configuration.enabled = false; configuration.pausedUntil = nil
                if helperStatus == .enabled, let saved = try await HelperClient.request() { configuration = saved }
                try? saveCache()
                helperNeedsRepair = false
            } catch {
                helperStatus = helper.status
                helperNeedsRepair = true
                self.error = "Couldn't refresh the background helper. Choose More options → Refresh background helper to retry. \(error.localizedDescription)"
            }
        }
    }

    func addSite(_ text: String) -> Bool {
        do {
            let site = try Site.normalize(text)
            guard !configuration.sites.contains(site) else { throw RefocusError.invalid("That website is already on your list.") }
            var desired = configuration; desired.sites.append(site)
            update(desired); return true
        } catch { self.error = error.localizedDescription; return false }
    }

    func removeSite(_ site: String) {
        var desired = configuration; desired.sites.removeAll { $0 == site }; update(desired)
    }
    func setEnabled(_ enabled: Bool) {
        var desired = configuration; desired.enabled = enabled; desired.pausedUntil = nil; update(desired)
    }
    func togglePause() {
        var desired = configuration
        desired.pausedUntil = isPaused ? nil : Date().addingTimeInterval(300)
        update(desired)
    }

    private func update(_ desired: Configuration) {
        guard !busy, !quitting else { return }
        error = nil
        do {
            let validated = try desired.validated()
            guard helperReady else {
                var local = validated; local.enabled = false; local.pausedUntil = nil
                configuration = local; try saveCache(); return
            }
            busy = true
            Task {
                defer { busy = false }
                do {
                    configuration = try await HelperClient.request(validated) ?? validated
                    try saveCache(); schedulePauseRefresh()
                } catch { self.error = error.localizedDescription; helperStatus = helper.status }
            }
        } catch { self.error = error.localizedDescription }
    }

    private func saveCache() throws {
        try FileManager.default.createDirectory(at: cache.deletingLastPathComponent(), withIntermediateDirectories: true)
        try RefocusJSON.encode(configuration).write(to: cache, options: .atomic)
    }

    private func schedulePauseRefresh() {
        pauseWakeup?.cancel(); pauseWakeup = nil
        guard let deadline = configuration.pausedUntil, deadline > Date() else { return }
        let item = DispatchWorkItem { [weak self] in self?.refresh() }
        pauseWakeup = item
        DispatchQueue.main.asyncAfter(deadline: .now() + deadline.timeIntervalSinceNow + 2, execute: item)
    }

    func setOpenAtLogin(_ enabled: Bool) {
        guard !quitting else { return }
        do {
            if enabled { try SMAppService.mainApp.register() }
            else { try SMAppService.mainApp.unregister() }
            openAtLogin = SMAppService.mainApp.status == .enabled
        } catch { self.error = error.localizedDescription }
    }

    func prepareToQuit() async -> Bool {
        guard !quitting else { return false }
        quitting = true
        pauseWakeup?.cancel(); pauseWakeup = nil
        while busy { try? await Task.sleep(nanoseconds: 50_000_000) }
        busy = true
        defer { busy = false }
        do {
            // A setup awaiting approval can quit freely when it has no system rules.
            // Existing rules still require confirmed cleanup if helper approval was revoked.
            let rulesPresent = try hasSystemRules()
            if helper.status == .enabled || rulesPresent {
                if let off = try await HelperClient.stopBlocking() { configuration = off }
            }
            guard try !hasSystemRules() else {
                throw RefocusError.invalid("Refocus's system rules haven't been removed yet.")
            }
            configuration.enabled = false; configuration.pausedUntil = nil
            defaults.removeObject(forKey: "EnableAfterApproval")
            // Cache errors must not strand an app whose system rules are already cleared.
            try? saveCache()
            return true
        } catch {
            self.error = "Couldn't turn blocking off, so Refocus stayed open. \(error.localizedDescription)"
            quitting = false
            schedulePauseRefresh()
            return false
        }
    }

    private func hasSystemRules() throws -> Bool {
        let contents = try String(contentsOfFile: "/private/etc/hosts", encoding: .utf8)
        return try HostsFile.removingRules(from: contents) != contents
    }

    func removeHelper() {
        guard !busy, !quitting else { return }
        busy = true; error = nil
        Task {
            defer { busy = false }
            do {
                // Remove our hosts block before unregistering; never strand active rules.
                var off = configuration; off.enabled = false; off.pausedUntil = nil
                configuration = try await HelperClient.request(off) ?? off
                try saveCache()
                try await helper.unregister()
                defaults.removeObject(forKey: "EnableAfterApproval")
                defaults.removeObject(forKey: "RegisteredHelperBuild")
                helperNeedsRepair = false
                helperStatus = helper.status
            } catch { self.error = "Couldn't remove the helper: \(error.localizedDescription)" }
        }
    }
}
