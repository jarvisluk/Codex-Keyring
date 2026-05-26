import Foundation

/// Minimal, *root-table-only* TOML editor for `~/.codex/config.toml`.
///
/// We deliberately do NOT use a full TOML parser. Codex stores its tracked
/// agent settings (`model`, `model_reasoning_effort`, `approval_policy`,
/// `approvals_reviewer`, `sandbox_mode`) as top-level scalar keys before any
/// `[section]` header. Everything below the first section header — project
/// trust levels, `[features]`, `[tui]`, custom user blocks, etc. — is left
/// byte-for-byte untouched, including comments, blank lines and trailing
/// whitespace.
///
/// Supported value types are limited to what Codex writes for these keys:
///   * Bare double-quoted strings (`key = "value"`).
///   * Booleans (`key = true` / `key = false`).
/// Anything else (arrays, inline tables, multi-line strings, dates) in the
/// root table is preserved verbatim but cannot be read or modified through
/// this editor.
public struct CodexConfigTomlEditor: Sendable {
    public init() {}

    // MARK: - Reading

    /// Read a string value from the root table. Returns `nil` if the key is
    /// missing, lives inside a `[section]`, or has a non-string value.
    public func readString(_ key: String, in source: String) -> String? {
        for line in rootTableLines(of: source) {
            if let value = parseKeyValueString(line: line, expectedKey: key) {
                return value
            }
        }
        return nil
    }

    /// Read a boolean value from the root table. Returns `nil` if absent or
    /// not a boolean literal.
    public func readBool(_ key: String, in source: String) -> Bool? {
        for line in rootTableLines(of: source) {
            if let value = parseKeyValueBool(line: line, expectedKey: key) {
                return value
            }
        }
        return nil
    }

    // MARK: - Writing

    public enum ScalarValue: Equatable, Sendable {
        case string(String)
        case bool(Bool)

        var rendered: String {
            switch self {
            case .string(let s): return "\"\(Self.escape(s))\""
            case .bool(let b): return b ? "true" : "false"
            }
        }

        private static func escape(_ value: String) -> String {
            var out = ""
            out.reserveCapacity(value.count)
            for scalar in value.unicodeScalars {
                switch scalar {
                case "\\": out += "\\\\"
                case "\"": out += "\\\""
                case "\n": out += "\\n"
                case "\r": out += "\\r"
                case "\t": out += "\\t"
                case "\u{08}": out += "\\b"
                case "\u{0C}": out += "\\f"
                default:
                    if scalar.value < 0x20 {
                        out += String(format: "\\u%04X", scalar.value)
                    } else {
                        out.unicodeScalars.append(scalar)
                    }
                }
            }
            return out
        }
    }

    /// Apply a set of root-table key updates. A value of `nil` is currently
    /// treated as "leave alone" — we never delete keys we didn't write, so a
    /// user who manually removed `model = "..."` from their TOML keeps that
    /// state. Returns the updated source string.
    public func applying(_ updates: [String: ScalarValue?], to source: String) -> String {
        // Normalise line endings: TOML is line-oriented, but we want to
        // preserve the original ending (LF vs CRLF) when we re-emit.
        let usesCRLF = source.contains("\r\n")
        let newline = usesCRLF ? "\r\n" : "\n"
        let trailingNewline = source.hasSuffix(newline) || source.hasSuffix("\n")

        // Foundation's `components(separatedBy:)` operates on UTF-16 code
        // units, so it splits a CRLF document correctly. Swift's
        // `split(whereSeparator:)` works on `Character` (extended grapheme
        // clusters) and treats `\r\n` as one indivisible grapheme, which
        // would collapse a CRLF document into a single line.
        var lines = source.components(separatedBy: "\n").map { line -> String in
            var l = line
            if l.hasSuffix("\r") { l.removeLast() }
            return l
        }

        // Locate the boundary of the root table = first line whose trimmed
        // prefix begins with '['.
        let rootEndIndex: Int = {
            for (idx, line) in lines.enumerated() where isSectionHeader(line: line) {
                return idx
            }
            return lines.count
        }()

        // 1. In-place updates for keys that already exist in the root table.
        var remaining = updates
        if !remaining.isEmpty {
            for idx in 0..<rootEndIndex {
                let line = lines[idx]
                guard let key = parsedKey(line: line), let pending = remaining[key] else { continue }
                if let pending {
                    lines[idx] = "\(key) = \(pending.rendered)"
                } // nil = leave existing line alone
                remaining[key] = nil
            }
        }

        // 2. Append still-missing keys at the END of the root table, just
        //    before the first `[section]` header. Skip nil pendings.
        let toAppend = remaining
            .compactMap { (key, value) -> (String, ScalarValue)? in
                guard let value else { return nil }
                return (key, value)
            }
            .sorted(by: { $0.0 < $1.0 })

        if !toAppend.isEmpty {
            var insertion = toAppend.map { "\($0.0) = \($0.1.rendered)" }
            // If the root table didn't end with a blank line, add one to keep
            // the new keys visually distinct from any prior content.
            let insertionPoint = rootEndIndex
            if insertionPoint > 0, !lines[insertionPoint - 1].isEmpty {
                insertion.insert("", at: 0)
            }
            // If we're inserting before a section header, also leave one
            // blank line between the appended keys and the section header.
            if insertionPoint < lines.count, !insertion.last!.isEmpty {
                insertion.append("")
            }
            lines.insert(contentsOf: insertion, at: insertionPoint)
        }

        var result = lines.joined(separator: newline)
        if trailingNewline, !result.hasSuffix(newline) {
            result += newline
        }
        return result
    }

    // MARK: - Parsing helpers

    /// Lines in the root table (before the first `[section]` header), with
    /// comments and blank lines included so callers can ignore them. Uses
    /// `components(separatedBy:)` so CRLF input is correctly split (see
    /// `applying(_:to:)` for the gory details).
    private func rootTableLines(of source: String) -> [String] {
        var out: [String] = []
        for raw in source.components(separatedBy: "\n") {
            var trimmedRight = raw
            if trimmedRight.hasSuffix("\r") { trimmedRight.removeLast() }
            if isSectionHeader(line: trimmedRight) { break }
            out.append(trimmedRight)
        }
        return out
    }

    private func isSectionHeader(line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !trimmed.hasPrefix("#") else { return false }
        return trimmed.hasPrefix("[")
    }

    /// Extract the key name from a `key = value` line, or `nil` if the line
    /// isn't a simple bare-key assignment. Bare keys are `[A-Za-z0-9_-]+`.
    private func parsedKey(line: String) -> String? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !trimmed.hasPrefix("#") else { return nil }
        guard let equalsIdx = trimmed.firstIndex(of: "=") else { return nil }
        let key = trimmed[..<equalsIdx].trimmingCharacters(in: .whitespaces)
        guard isBareKey(key) else { return nil }
        return key
    }

    private func isBareKey(_ s: String) -> Bool {
        guard !s.isEmpty else { return false }
        return s.unicodeScalars.allSatisfy { scalar in
            (scalar >= "A" && scalar <= "Z")
                || (scalar >= "a" && scalar <= "z")
                || (scalar >= "0" && scalar <= "9")
                || scalar == "_"
                || scalar == "-"
        }
    }

    private func parseKeyValueString(line: String, expectedKey: String) -> String? {
        guard let (key, valuePart) = splitKeyValue(line: line), key == expectedKey else { return nil }
        return decodeBasicString(valuePart)
    }

    private func parseKeyValueBool(line: String, expectedKey: String) -> Bool? {
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

    private func splitKeyValue(line: String) -> (String, String)? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !trimmed.hasPrefix("#") else { return nil }
        guard let equalsIdx = trimmed.firstIndex(of: "=") else { return nil }
        let keyPart = trimmed[..<equalsIdx].trimmingCharacters(in: .whitespaces)
        let valuePart = trimmed[trimmed.index(after: equalsIdx)...].trimmingCharacters(in: .whitespaces)
        guard isBareKey(keyPart) else { return nil }
        return (keyPart, String(valuePart))
    }

    /// Decode a TOML basic string `"..."` (with the standard escape set).
    /// Returns `nil` for literal strings (`'...'`) or any non-string value.
    private func decodeBasicString(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespaces)
        guard trimmed.first == "\"" else { return nil }
        let chars = Array(trimmed)
        var idx = 1
        var out = ""
        while idx < chars.count {
            let c = chars[idx]
            if c == "\\" {
                guard idx + 1 < chars.count else { return nil }
                let next = chars[idx + 1]
                switch next {
                case "\"": out.append("\""); idx += 2
                case "\\": out.append("\\"); idx += 2
                case "n":  out.append("\n"); idx += 2
                case "r":  out.append("\r"); idx += 2
                case "t":  out.append("\t"); idx += 2
                case "b":  out.append("\u{08}"); idx += 2
                case "f":  out.append("\u{0C}"); idx += 2
                case "u":
                    guard idx + 5 < chars.count else { return nil }
                    let hex = String(chars[(idx + 2)...(idx + 5)])
                    guard let scalarValue = UInt32(hex, radix: 16),
                          let scalar = Unicode.Scalar(scalarValue) else { return nil }
                    out.unicodeScalars.append(scalar)
                    idx += 6
                default:
                    return nil
                }
            } else if c == "\"" {
                // End of string. Anything after must be whitespace or comment.
                let rest = String(chars[(idx + 1)...]).trimmingCharacters(in: .whitespaces)
                if rest.isEmpty || rest.hasPrefix("#") { return out }
                return nil
            } else {
                out.append(c)
                idx += 1
            }
        }
        return nil
    }

    /// Drop a trailing `# ...` comment (respecting `#` inside a quoted string
    /// would matter here, but for booleans there is no quoting so we just cut
    /// at the first `#`).
    private func stripTrailingComment(_ s: String) -> String {
        if let hashIdx = s.firstIndex(of: "#") { return String(s[..<hashIdx]) }
        return s
    }
}
