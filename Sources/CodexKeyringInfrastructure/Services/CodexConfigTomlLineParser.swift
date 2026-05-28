import Foundation

enum CodexConfigTomlLineParser {
    /// Lines in the root table (before the first `[section]` header), with
    /// comments and blank lines included so callers can ignore them. Uses
    /// `components(separatedBy:)` so CRLF input is correctly split.
    static func rootTableLines(of source: String) -> [String] {
        var out: [String] = []
        for raw in source.components(separatedBy: "\n") {
            var trimmedRight = raw
            if trimmedRight.hasSuffix("\r") { trimmedRight.removeLast() }
            if isSectionHeader(line: trimmedRight) { break }
            out.append(trimmedRight)
        }
        return out
    }

    static func isSectionHeader(line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !trimmed.hasPrefix("#") else { return false }
        return trimmed.hasPrefix("[")
    }
}
