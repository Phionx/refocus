import Foundation
import Darwin

let root = URL(fileURLWithPath: CommandLine.arguments[1]).standardizedFileURL
let patterns = [
    #"/(?:Users|home)/[^/\s\x00]+/"#,
    #"/(?:private/)?var/folders/[^\s\x00]+"#,
    #"[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}"#,
    #"-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----"#
]
let expressions = try patterns.map { try NSRegularExpression(pattern: $0) }
let forbiddenNames: Set<String> = [".DS_Store", "configuration.json", "state.json", ".env", "hosts", ".git"]
let forbiddenExtensions: Set<String> = ["p12", "p8", "key", "mobileprovision", "provisionprofile", "dSYM"]
var findings: [String] = []
let enumerator = FileManager.default.enumerator(at: root, includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey])!
let files = [root] + enumerator.compactMap { $0 as? URL }
for file in files {
    let relative = file == root ? root.lastPathComponent : String(file.path.dropFirst(root.path.count + 1))
    if !CommandLine.arguments.contains("--content-only") {
        let count = listxattr(file.path, nil, 0, XATTR_NOFOLLOW)
        if count < 0 { throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno)) }
        if count > 0 {
            var names = [CChar](repeating: 0, count: count)
            guard listxattr(file.path, &names, count, XATTR_NOFOLLOW) == count else {
                throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno))
            }
            let attributes = String(decoding: names.map { UInt8(bitPattern: $0) }, as: UTF8.self).split(separator: "\0")
            for attribute in attributes {
                let name = String(attribute)
                // HFS image creation adds a generic "no icon position" FinderInfo record.
                // Permit only that fixed record or an empty one, never custom positions or origin data.
                if name == "com.apple.FinderInfo" {
                    var bytes = [UInt8](repeating: 0, count: 32)
                    let read = bytes.withUnsafeMutableBytes {
                        getxattr(file.path, name, $0.baseAddress, $0.count, 0, XATTR_NOFOLLOW)
                    }
                    var defaultInfo = [UInt8](repeating: 0, count: 32)
                    for index in 10...13 { defaultInfo[index] = 255 }
                    if read == 32 && (bytes.allSatisfy({ $0 == 0 }) || bytes == defaultInfo) { continue }
                }
                findings.append("Unexpected metadata (" + name + ") in: " + relative)
            }
        }
    }
    if forbiddenNames.contains(file.lastPathComponent) || forbiddenExtensions.contains(file.pathExtension) {
        findings.append("Unwanted bundled file: " + relative)
    }
    let values = try file.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
    guard values.isRegularFile == true, values.isSymbolicLink != true else { continue }
    let data = try Data(contentsOf: file)
    let contents = String(decoding: data, as: UTF8.self)
    let range = NSRange(contents.startIndex..., in: contents)
    if expressions.contains(where: { $0.firstMatch(in: contents, range: range) != nil }) {
        findings.append("Possible personal build data or credential in: " + relative)
    }
}
if !findings.isEmpty {
    for finding in findings { fputs(finding + "\n", stderr) }
    exit(1)
}
print("PASS App payload has no detected personal paths, email addresses, keys, or local settings")
if !CommandLine.arguments.contains("--content-only") { print("PASS Packaged app has no identifying extended metadata") }
