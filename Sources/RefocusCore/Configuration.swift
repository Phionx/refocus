import Foundation

public enum RefocusError: LocalizedError {
    case invalid(String)
    public var errorDescription: String? {
        switch self { case .invalid(let message): return message }
    }
}

public enum Site {
    public static func normalize(_ input: String) throws -> String {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !text.contains(where: { $0.isWhitespace }),
              let url = URL(string: text.contains("://") ? text : "https://" + text),
              let scheme = url.scheme?.lowercased(), ["http", "https"].contains(scheme),
              url.user == nil, url.password == nil, let hostname = url.host else {
            throw RefocusError.invalid("Enter a website such as reddit.com.")
        }
        var host = hostname.lowercased()
        if host.hasSuffix(".") { host.removeLast() }
        if host.hasPrefix("www.") { host = String(host.dropFirst(4)) }
        let labels = host.split(separator: ".", omittingEmptySubsequences: false)
        guard host.utf8.count <= 253, labels.count >= 2,
              labels.allSatisfy({ label in
                  !label.isEmpty && label.utf8.count <= 63 && label.first != "-" && label.last != "-" &&
                  label.utf8.allSatisfy { (97...122).contains($0) || (48...57).contains($0) || $0 == 45 }
              }),
              labels.last!.contains(where: { $0.isLetter }),
              !["local", "localhost", "invalid", "test"].contains(String(labels.last!)) else {
            throw RefocusError.invalid("Enter a public website name, rather than an IP address or local host.")
        }
        return host
    }

    public static func hostnames(for domain: String) -> Set<String> {
        var names: Set<String> = [domain, "www." + domain]
        if let preset = SiteAliases.presets.first(where: { $0.entries.contains(domain) }) {
            names.formUnion(preset.aliases)
        }
        return names
    }
}

public struct Configuration: Codable, Equatable {
    public var sites: [String]
    public var enabled: Bool
    public var pausedUntil: Date?

    public init(sites: [String] = ["reddit.com", "instagram.com", "x.com"], enabled: Bool = false, pausedUntil: Date? = nil) {
        self.sites = sites; self.enabled = enabled; self.pausedUntil = pausedUntil
    }

    public func isBlocking(at date: Date = Date()) -> Bool {
        enabled && !(pausedUntil.map { $0 > date } ?? false)
    }

    public func validated(at date: Date = Date()) throws -> Configuration {
        guard sites.count <= 500 else { throw RefocusError.invalid("You can add up to 500 websites.") }
        var copy = self
        var seen = Set<String>()
        copy.sites = try sites.map(Site.normalize).filter { seen.insert($0).inserted }
        if let deadline = pausedUntil {
            guard deadline.timeIntervalSince1970.isFinite, deadline <= date.addingTimeInterval(86400) else {
                throw RefocusError.invalid("A pause can last at most one day.")
            }
            if deadline <= date || !enabled { copy.pausedUntil = nil }
        }
        return copy
    }

    public var hostnames: [String] {
        Set(sites.flatMap { Site.hostnames(for: $0) }).sorted()
    }
}

public enum RefocusJSON {
    public static func encode<T: Encodable>(_ value: T) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(value)
    }
    public static func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(type, from: data)
    }
}
