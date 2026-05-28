import Foundation

struct CodexConfigTomlDocument {
    var lines: [String]
    private let newline: String
    private let trailingNewline: Bool

    init(source: String) {
        let usesCRLF = source.contains("\r\n")
        newline = usesCRLF ? "\r\n" : "\n"
        trailingNewline = source.hasSuffix(newline) || source.hasSuffix("\n")
        lines = Self.normalizedLines(from: source)
    }

    var rootEndIndex: Int {
        for (idx, line) in lines.enumerated()
        where CodexConfigTomlLineParser.isSectionHeader(line: line) {
            return idx
        }
        return lines.count
    }

    func rendered() -> String {
        var result = lines.joined(separator: newline)
        if trailingNewline, !result.hasSuffix(newline) {
            result += newline
        }
        return result
    }

    private static func normalizedLines(from source: String) -> [String] {
        source.components(separatedBy: "\n").map { line -> String in
            var normalized = line
            if normalized.hasSuffix("\r") {
                normalized.removeLast()
            }
            return normalized
        }
    }
}
