import Foundation
import Darwin
import MachO
import RefocusCore

private final class Session: NSObject, RefocusHelperProtocol {
    let engine: BlockingEngine
    let uid: uid_t
    let pid: pid_t
    init(engine: BlockingEngine, uid: uid_t, pid: pid_t) {
        self.engine = engine; self.uid = uid; self.pid = pid
    }

    func readConfiguration(reply: @escaping (Data?, String?) -> Void) {
        engine.queue.async {
            do {
                if let config = try self.engine.read(for: self.uid) { reply(try RefocusJSON.encode(config), nil) }
                else { reply(nil, nil) }
            }
            catch { reply(nil, error.localizedDescription) }
        }
    }
    func disableBlocking(reply: @escaping (Data?, String?) -> Void) {
        engine.queue.async {
            do {
                if let config = try self.engine.stop(for: self.uid) { reply(try RefocusJSON.encode(config), nil) }
                else { reply(nil, nil) }
            } catch { reply(nil, error.localizedDescription) }
        }
    }
    func applyConfiguration(_ data: Data, reply: @escaping (Data?, String?) -> Void) {
        guard data.count < 256_000 else { reply(nil, "The settings request is too large."); return }
        engine.queue.async {
            do {
                let configuration = try RefocusJSON.decode(Configuration.self, from: data)
                reply(try RefocusJSON.encode(self.engine.apply(configuration, for: self.uid, process: self.pid)), nil)
            } catch { reply(nil, error.localizedDescription) }
        }
    }
}

private final class Listener: NSObject, NSXPCListenerDelegate {
    let engine = BlockingEngine(onHostsChanged: {
        for (path, arguments) in [("/usr/bin/dscacheutil", ["-flushcache"]), ("/usr/bin/killall", ["-HUP", "mDNSResponder"])] {
            let process = Process(); process.executableURL = URL(fileURLWithPath: path); process.arguments = arguments
            process.standardOutput = FileHandle.nullDevice; process.standardError = FileHandle.nullDevice
            do { try process.run(); process.waitUntilExit() }
            catch { NSLog("Refocus cache refresh: %@", error.localizedDescription) }
        }
    }, onIdle: { exit(EXIT_SUCCESS) })
    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection connection: NSXPCConnection) -> Bool {
        guard connection.effectiveUserIdentifier != 0 else { return false }
        connection.exportedInterface = NSXPCInterface(with: RefocusHelperProtocol.self)
        connection.exportedObject = Session(engine: engine, uid: connection.effectiveUserIdentifier, pid: connection.processIdentifier)
        connection.resume()
        return true
    }
}

guard geteuid() == 0 else {
    fputs("RefocusHelper is started by macOS after approval in the Refocus app.\n", stderr)
    exit(EXIT_FAILURE)
}

do {
    // launchd may supply a relative argv[0] for BundleProgram; ask dyld for the real image path.
    var pathSize: UInt32 = 0
    _ = _NSGetExecutablePath(nil, &pathSize)
    var pathBuffer = [CChar](repeating: 0, count: Int(pathSize))
    guard _NSGetExecutablePath(&pathBuffer, &pathSize) == 0 else {
        throw RefocusError.invalid("Couldn't locate the running helper.")
    }
    let executable = URL(fileURLWithPath: String(cString: pathBuffer)).resolvingSymlinksInPath()
    let app = executable.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    guard app.pathExtension == "app", Bundle(url: app)?.bundleIdentifier == "org.refocus.app" else {
        throw RefocusError.invalid("The helper must run from the signed Refocus app bundle.")
    }
    let delegate = Listener()
    let listener = NSXPCListener(machServiceName: RefocusService.name)
    // An exact designated requirement pins ad-hoc builds; Developer ID builds pin their signer.
    listener.setConnectionCodeSigningRequirement(try Signing.requirement(for: app))
    listener.delegate = delegate
    delegate.engine.queue.async {
        do { try delegate.engine.resetAfterRestart() }
        catch { NSLog("Refocus startup: %@", error.localizedDescription) }
    }
    listener.resume()
    withExtendedLifetime(delegate) { dispatchMain() }
} catch {
    NSLog("RefocusHelper: %@", error.localizedDescription)
    exit(EXIT_FAILURE)
}
