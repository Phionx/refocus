import Foundation
import RefocusCore

private final class ReplyGate {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<Configuration?, Error>?
    var connection: NSXPCConnection?
    init(_ continuation: CheckedContinuation<Configuration?, Error>) { self.continuation = continuation }
    func finish(_ result: Result<Configuration?, Error>) {
        lock.lock()
        guard let continuation else { lock.unlock(); return }
        self.continuation = nil
        let connection = self.connection
        self.connection = nil
        lock.unlock()
        connection?.invalidationHandler = nil
        connection?.interruptionHandler = nil
        connection?.invalidate()
        continuation.resume(with: result)
    }
}

enum HelperClient {
    static func request(_ configuration: Configuration? = nil) async throws -> Configuration? {
        try await perform(configuration)
    }
    static func stopBlocking() async throws -> Configuration? {
        let result = try await perform(nil, stopping: true)
        guard result?.enabled != true, result?.pausedUntil == nil else {
            throw RefocusError.invalid("The helper hasn't confirmed that blocking is off.")
        }
        return result
    }
    private static func perform(_ configuration: Configuration?, stopping: Bool = false) async throws -> Configuration? {
        guard let executable = Bundle.main.executableURL?.deletingLastPathComponent().appendingPathComponent("RefocusHelper") else {
            throw RefocusError.invalid("Open Refocus.app rather than its bare executable.")
        }
        let requirement = try Signing.requirement(for: executable)
        let data = try configuration.map { try RefocusJSON.encode($0) }
        return try await withCheckedThrowingContinuation { continuation in
            let gate = ReplyGate(continuation)
            let connection = NSXPCConnection(machServiceName: RefocusService.name, options: .privileged)
            gate.connection = connection
            connection.remoteObjectInterface = NSXPCInterface(with: RefocusHelperProtocol.self)
            connection.setCodeSigningRequirement(requirement)
            let disconnected = { gate.finish(.failure(RefocusError.invalid("The blocking helper isn't available. Check its approval in System Settings → General → Login Items."))) }
            connection.invalidationHandler = disconnected
            connection.interruptionHandler = disconnected
            connection.resume()
            DispatchQueue.global().asyncAfter(deadline: .now() + 12) {
                gate.finish(.failure(RefocusError.invalid("The helper didn't respond. Check its approval in System Settings → General → Login Items.")))
            }
            guard let proxy = connection.remoteObjectProxyWithErrorHandler({ error in
                gate.finish(.failure(RefocusError.invalid("Couldn't reach the helper: \(error.localizedDescription)")))
            }) as? RefocusHelperProtocol else { disconnected(); return }
            let reply: (Data?, String?) -> Void = { response, error in
                if let error { gate.finish(.failure(RefocusError.invalid(error))); return }
                do {
                    let result = try response.map { try RefocusJSON.decode(Configuration.self, from: $0) }
                    if configuration != nil && result == nil { throw RefocusError.invalid("The helper returned an empty response.") }
                    gate.finish(.success(result))
                } catch { gate.finish(.failure(error)) }
            }
            if stopping { proxy.disableBlocking(reply: reply) }
            else if let data { proxy.applyConfiguration(data, reply: reply) }
            else { proxy.readConfiguration(reply: reply) }
        }
    }
}
