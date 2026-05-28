import Foundation

extension CodexConfigTomlLineParser {
    /// Decode a TOML basic string `"..."` (with the standard escape set).
    /// Returns `nil` for literal strings (`'...'`) or any non-string value.
    static func decodeBasicString(_ value: String) -> String? {
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
                case "n": out.append("\n"); idx += 2
                case "r": out.append("\r"); idx += 2
                case "t": out.append("\t"); idx += 2
                case "b": out.append("\u{08}"); idx += 2
                case "f": out.append("\u{0C}"); idx += 2
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
}
