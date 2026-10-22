import Foundation
import Darwin

public enum HostsFile {
    public static let begin = "# BEGIN REFOCUS - managed by Refocus"
    public static let end = "# END REFOCUS"

    public static func removingRules(from original: String) throws -> String {
        // Keep every byte outside the owned block, including its original final newline.
        var start: String.Index?
        var finish: String.Index?
        var cursor = original.startIndex
        while cursor < original.endIndex {
            let newline = original[cursor...].firstIndex(of: "\n")
            let lineEnd = newline ?? original.endIndex
            let next = newline.map { original.index(after: $0) } ?? original.endIndex
            let line = original[cursor..<lineEnd].trimmingCharacters(in: .whitespacesAndNewlines)
            if line == begin {
                guard start == nil && finish == nil else { throw malformed() }
                start = cursor
            } else if line == end {
                guard start != nil && finish == nil else { throw malformed() }
                finish = next
            }
            cursor = next
        }
        if start == nil && finish == nil { return original }
        guard let first = start, let last = finish else { throw malformed() }
        return String(original[..<first]) + String(original[last...])
    }

    public static func rendering(_ original: String, configuration: Configuration, at date: Date = Date()) throws -> String {
        let config = try configuration.validated(at: date)
        let clean = try removingRules(from: original)
        guard config.isBlocking(at: date), !config.sites.isEmpty else { return clean }
        let separator = clean.isEmpty || clean.hasSuffix("\n") ? "" : "\n"
        let rules = config.hostnames.map { "0.0.0.0 \($0)\n:: \($0)" }.joined(separator: "\n")
        return clean + separator + begin + "\n" + rules + "\n" + end + "\n"
    }

    private static func malformed() -> RefocusError {
        .invalid("The Refocus section in /etc/hosts is incomplete or duplicated. No changes were made.")
    }
}

public enum AtomicFile {
    // A new file is complete, permissioned and flushed before it replaces the old one.
    public static func write(_ data: Data, to url: URL, mode: mode_t, owner: uid_t, group: gid_t) throws {
        let temporary = url.deletingLastPathComponent().appendingPathComponent(".refocus-" + UUID().uuidString)
        let fd = open(temporary.path, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW, mode)
        guard fd >= 0 else { throw posix("create a temporary file") }
        defer { close(fd); unlink(temporary.path) }
        guard fchmod(fd, mode) == 0, fchown(fd, owner, group) == 0 else { throw posix("preserve file permissions") }
        try data.withUnsafeBytes { buffer in
            var offset = 0
            while offset < buffer.count {
                let count = Darwin.write(fd, buffer.baseAddress!.advanced(by: offset), buffer.count - offset)
                if count < 0 && errno == EINTR { continue }
                guard count > 0 else { throw posix("write a file") }
                offset += count
            }
        }
        guard fsync(fd) == 0, rename(temporary.path, url.path) == 0 else { throw posix("save a file") }
    }

    public static func posix(_ action: String) -> RefocusError {
        .invalid("Couldn't \(action): \(String(cString: strerror(errno))).")
    }
}

public final class HostsStore {
    private let url: URL
    private let owner: uid_t
    public init(url: URL = URL(fileURLWithPath: "/private/etc/hosts"), owner: uid_t = 0) {
        self.url = url; self.owner = owner
    }
    @discardableResult public func apply(_ configuration: Configuration, at date: Date = Date()) throws -> Bool {
        let fd = open(url.path, O_RDONLY | O_NOFOLLOW)
        guard fd >= 0 else { throw AtomicFile.posix("open the hosts file") }
        defer { close(fd) }
        var info = stat()
        guard fstat(fd, &info) == 0, info.st_mode & S_IFMT == S_IFREG, info.st_uid == owner,
              info.st_mode & 0o022 == 0, info.st_size <= 4_000_000 else {
            throw RefocusError.invalid("The hosts file has unexpected ownership, permissions, or size. No changes were made.")
        }
        let data = try FileHandle(fileDescriptor: fd, closeOnDealloc: false).readToEnd() ?? Data()
        guard let original = String(data: data, encoding: .utf8) else {
            throw RefocusError.invalid("The hosts file isn't UTF-8 text. No changes were made.")
        }
        let next = try HostsFile.rendering(original, configuration: configuration, at: date)
        guard next != original else { return false }
        // Don't overwrite a concurrent edit made while this update was prepared.
        guard try Data(contentsOf: url) == data else {
            throw RefocusError.invalid("Another app changed /etc/hosts. Please try again.")
        }
        try AtomicFile.write(Data(next.utf8), to: url, mode: info.st_mode & 0o777, owner: info.st_uid, group: info.st_gid)
        return true
    }
}
