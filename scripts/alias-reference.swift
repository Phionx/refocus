import Foundation
import RefocusCore

var document = """
# Website aliases

Generated from [the editable catalog](Sources/RefocusCore/SiteAliases.swift).
Edit that file, then run `bash scripts/update-aliases.sh` to update this reference.

Every entry blocks itself and its `www` form. A listed entry also adds the exact
aliases below. Other subdomains stay narrow. Removing a site removes its aliases,
unless another listed entry still selects them.

See [DNS observations and shared-server limits](docs/site-aliases.md) before adding
fallback targets. Avoid shared CDN infrastructure and IP addresses.

"""
for preset in SiteAliases.presets {
    document += "\n## \(preset.name)\n\n"
    document += "Add any of: " + preset.entries.map { "`" + $0 + "`" }.joined(separator: ", ") + ".\n\n"
    document += "Additional aliases:\n\n```text\n" + preset.aliases.joined(separator: "\n") + "\n```\n"
}
if CommandLine.arguments.count == 3, CommandLine.arguments[1] == "--check" {
    let existing = try String(contentsOfFile: CommandLine.arguments[2], encoding: .utf8)
    guard existing == document else {
        fputs("SITE_ALIASES.md is stale. Run bash scripts/update-aliases.sh.\n", stderr)
        exit(1)
    }
    print("PASS Alias reference matches the editable catalog")
} else {
    FileHandle.standardOutput.write(Data(document.utf8))
}
