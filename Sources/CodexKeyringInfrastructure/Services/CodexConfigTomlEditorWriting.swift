import Foundation

extension CodexConfigTomlEditor {
    /// Apply a set of root-table key updates. A value of `nil` is currently
    /// treated as "leave alone" — we never delete keys we didn't write, so a
    /// user who manually removed `model = "..."` from their TOML keeps that
    /// state. Returns the updated source string.
    public func applying(_ updates: [String: ScalarValue?], to source: String) -> String {
        var document = CodexConfigTomlDocument(source: source)
        let rootEndIndex = document.rootEndIndex

        // 1. In-place updates for keys that already exist in the root table.
        var remaining = updates
        if !remaining.isEmpty {
            for idx in 0..<rootEndIndex {
                let line = document.lines[idx]
                guard let key = CodexConfigTomlLineParser.parsedKey(line: line),
                      let pending = remaining[key] else { continue }
                if let pending {
                    document.lines[idx] = "\(key) = \(pending.rendered)"
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
            if insertionPoint > 0, !document.lines[insertionPoint - 1].isEmpty {
                insertion.insert("", at: 0)
            }
            // If we're inserting before a section header, also leave one
            // blank line between the appended keys and the section header.
            if insertionPoint < document.lines.count, insertion.last?.isEmpty == false {
                insertion.append("")
            }
            document.lines.insert(contentsOf: insertion, at: insertionPoint)
        }

        return document.rendered()
    }
}
