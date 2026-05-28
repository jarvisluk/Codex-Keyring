import Foundation

extension CodexConfigTomlLineParser {
    /// Extract the key name from a `key = value` line, or `nil` if the line
    /// isn't a simple bare-key assignment. Bare keys are `[A-Za-z0-9_-]+`.
    static func parsedKey(line: String) -> String? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !trimmed.hasPrefix("#") else { return nil }
        guard let equalsIdx = trimmed.firstIndex(of: "=") else { return nil }
        let key = trimmed[..<equalsIdx].trimmingCharacters(in: .whitespaces)
        guard isBareKey(key) else { return nil }
        return key
    }

    static func parseKeyValueString(line: String, expectedKey: String) -> String? {
        guard let (key, valuePart) = splitKeyValue(line: line), key == expectedKey else { return nil }
        return decodeBasicString(valuePart)
    }

    static func parseKeyValueBool(line: String, expectedKey: String) -> Bool? {
        guard let (key, valuePart) = splitKeyValue(line: line), key == expectedKey else { return nil }
        let trimmed = valuePart.trimmingCharacters(in: .whitespaces)
        let beforeComment = stripTrailingComment(trimmed)
            .trimmingCharacters(in: .whitespaces)
        switch beforeComment {
        case "true": return true
        case "false": return false
        default: return nil
        }
    }

    private static func splitKeyValue(line: String) -> (String, String)? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !trimmed.hasPrefix("#") else { return nil }
        guard let equalsIdx = trimmed.firstIndex(of: "=") else { return nil }
        let keyPart = trimmed[..<equalsIdx].trimmingCharacters(in: .whitespaces)
        let valuePart = trimmed[trimmed.index(after: equalsIdx)...].trimmingCharacters(in: .whitespaces)
        guard isBareKey(keyPart) else { return nil }
        return (keyPart, String(valuePart))
    }

    private static func isBareKey(_ s: String) -> Bool {
        guard !s.isEmpty else { return false }
        return s.unicodeScalars.allSatisfy { scalar in
            (scalar >= "A" && scalar <= "Z")
                || (scalar >= "a" && scalar <= "z")
                || (scalar >= "0" && scalar <= "9")
                || scalar == "_"
                || scalar == "-"
        }
    }

    /// Drop a trailing `# ...` comment (respecting `#` inside a quoted string
    /// would matter here, but for booleans there is no quoting so we just cut
    /// at the first `#`).
    private static func stripTrailingComment(_ s: String) -> String {
        if let hashIdx = s.firstIndex(of: "#") { return String(s[..<hashIdx]) }
        return s
    }
}
