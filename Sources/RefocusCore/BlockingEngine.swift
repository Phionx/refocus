import Foundation
import Darwin

private struct SavedState: Codable {
    var owner: uid_t
    var configuration: Configuration
}

// All methods and callbacks run on queue. Paths are fixed by the helper, never by XPC clients.
public final class BlockingEngine {
    public let queue = DispatchQueue(label: "org.refocus.app.enforcement")
    private let directory: URL
    private let fileOwner: uid_t
    private let fileGroup: gid_t
    private let hosts: HostsStore
    private let onHostsChanged: () -> Void
    private let onIdle: () -> Void
    private var timer: DispatchSourceTimer?
    private var idle: DispatchWorkItem?
    private var cleanupRetry: DispatchWorkItem?
    private var processMonitor: AppProcessMonitor?
    private var watchID: UUID?
    private var stateURL: URL { directory.appendingPathComponent("state.json") }

    public init(directory: URL = URL(fileURLWithPath: "/Library/Application Support/Refocus"),
                fileOwner: uid_t = 0, fileGroup: gid_t = 0, hosts: HostsStore = HostsStore(),
                onHostsChanged: @escaping () -> Void = {}, onIdle: @escaping () -> Void = {}) {
        self.directory = directory; self.fileOwner = fileOwner; self.fileGroup = fileGroup
        self.hosts = hosts; self.onHostsChanged = onHostsChanged; self.onIdle = onIdle
    }

    private func prepareDirectory() throws {
        if mkdir(directory.path, 0o700) != 0 && errno != EEXIST { throw AtomicFile.posix("create Refocus's settings folder") }
        var info = stat()
        guard lstat(directory.path, &info) == 0, info.st_mode & S_IFMT == S_IFDIR,
              info.st_uid == fileOwner, info.st_mode & 0o077 == 0 else {
            throw RefocusError.invalid("Refocus's system settings folder has unexpected permissions.")
        }
    }

    private func load() throws -> SavedState? {
        try prepareDirectory()
        var info = stat()
        if lstat(stateURL.path, &info) != 0 {
            if errno == ENOENT { return nil }
            throw AtomicFile.posix("read Refocus's settings")
        }
        guard info.st_mode & S_IFMT == S_IFREG, info.st_uid == fileOwner,
              info.st_mode & 0o077 == 0, info.st_size < 256_000 else {
            throw RefocusError.invalid("Refocus's system settings have unexpected permissions or size.")
        }
        do { return try RefocusJSON.decode(SavedState.self, from: Data(contentsOf: stateURL)) }
        catch { throw RefocusError.invalid("Refocus's saved system settings couldn't be read.") }
    }

    private func save(_ state: SavedState) throws {
        try AtomicFile.write(RefocusJSON.encode(state), to: stateURL, mode: 0o600, owner: fileOwner, group: fileGroup)
    }

    private func updateHosts(_ config: Configuration) throws {
        if try hosts.apply(config) { onHostsChanged() }
    }

    // A helper restart or reboot never restores blocking without a live app session.
    public func resetAfterRestart() throws {
        clearMonitor()
        schedule(Configuration(enabled: false))
        try updateHosts(Configuration(sites: [], enabled: false))
        if var state = try load() {
            state.configuration.enabled = false; state.configuration.pausedUntil = nil
            try save(state)
        }
    }

    public func reconcile() throws {
        if var state = try load() {
            state.configuration = try state.configuration.validated()
            if processMonitor == nil || processMonitor?.hasExited == true {
                state.configuration.enabled = false; state.configuration.pausedUntil = nil
            }
            try save(state)
            try updateHosts(state.configuration)
            if !state.configuration.enabled { clearMonitor() }
            schedule(state.configuration)
        } else { schedule(Configuration()) }
    }

    private func schedule(_ config: Configuration) {
        timer?.cancel(); timer = nil
        idle?.cancel(); idle = nil
        cleanupRetry?.cancel(); cleanupRetry = nil
        if config.enabled, let deadline = config.pausedUntil, deadline > Date() {
            let timer = DispatchSource.makeTimerSource(queue: queue)
            let time = deadline.timeIntervalSince1970
            let wallTime = timespec(tv_sec: Int(time), tv_nsec: Int((time - floor(time)) * 1_000_000_000))
            timer.schedule(wallDeadline: DispatchWallTime(timespec: wallTime), leeway: .seconds(1))
            timer.setEventHandler { [weak self] in
                do { try self?.reconcile() }
                catch {
                    NSLog("Refocus resume failed: %@", error.localizedDescription)
                    self?.timer?.schedule(deadline: .now() + 10)
                }
            }
            self.timer = timer; timer.resume()
        } else if !config.enabled {
            let task = DispatchWorkItem { [onIdle] in onIdle() }
            idle = task; queue.asyncAfter(deadline: .now() + 60, execute: task)
        }
        // While enabled, retain the process exit notification (no polling or idle exit).
    }

    public func read(for uid: uid_t) throws -> Configuration? {
        try checkOwner(try load(), uid: uid)
        try reconcile()
        return try load()?.configuration
    }

    private func checkOwner(_ state: SavedState?, uid: uid_t) throws {
        guard state == nil || state!.owner == uid else {
            throw RefocusError.invalid("Blocking is managed by another Mac account.")
        }
    }

    public func apply(_ config: Configuration, for uid: uid_t, process pid: pid_t) throws -> Configuration {
        let config = try config.validated()
        let previous = try load()
        try checkOwner(previous, uid: uid)
        let id = UUID()
        let monitor = try config.enabled ? AppProcessMonitor(pid: pid, queue: queue) { [weak self] in
            self?.appExited(id: id, uid: uid)
        } : nil
        try save(SavedState(owner: uid, configuration: config))
        do { try updateHosts(config) }
        catch {
            if let previous { try? save(previous) } else { try? FileManager.default.removeItem(at: stateURL) }
            throw error
        }
        clearMonitor()
        processMonitor = monitor; watchID = config.enabled ? id : nil
        schedule(config)
        return config
    }

    // Preserve the helper's latest list, including edits that were in flight when Quit was chosen.
    public func stop(for uid: uid_t) throws -> Configuration? {
        let previous = try load()
        try checkOwner(previous, uid: uid)
        guard let previous else {
            try updateHosts(Configuration(sites: [], enabled: false))
            clearMonitor(); schedule(Configuration())
            return nil
        }
        var off = previous.configuration; off.enabled = false; off.pausedUntil = nil
        return try apply(off, for: uid, process: 0)
    }

    private func clearMonitor() {
        processMonitor = nil; watchID = nil
    }

    private func appExited(id: UUID, uid: uid_t) {
        guard watchID == id else { return }
        do { _ = try stop(for: uid) }
        catch {
            NSLog("Refocus exit cleanup failed; retrying: %@", error.localizedDescription)
            let retry = DispatchWorkItem { [weak self] in self?.appExited(id: id, uid: uid) }
            cleanupRetry = retry; queue.asyncAfter(deadline: .now() + 5, execute: retry)
        }
    }
}

private final class AppProcessMonitor {
    private let source: DispatchSourceProcess
    private var finished = false
    var hasExited: Bool { finished }
    private let onExit: () -> Void

    init(pid: pid_t, queue: DispatchQueue, onExit: @escaping () -> Void) throws {
        guard pid > 0, kill(pid, 0) == 0 else {
            throw RefocusError.invalid("Refocus must be running to enable blocking.")
        }
        self.onExit = onExit
        source = DispatchSource.makeProcessSource(identifier: pid, eventMask: .exit, queue: queue)
        source.setEventHandler { [weak self] in self?.exited() }
        // Source registration is asynchronous. Cover an app that exits before registration.
        source.setRegistrationHandler { [weak self] in
            if kill(pid, 0) != 0 && errno == ESRCH { self?.exited() }
        }
        source.resume()
    }

    private func exited() {
        guard !finished else { return }
        finished = true; source.cancel(); onExit()
    }
    deinit { source.cancel() }
}
