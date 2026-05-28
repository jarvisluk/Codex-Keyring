import Foundation

extension CodexGlobalStateEditor {
    /// Write `value` at the given dotted path, creating any missing parent
    /// dictionaries. Returns the updated JSON bytes. `value == nil` removes
    /// the leaf key (and does NOT clean up newly-empty parents).
    public func writing(_ value: Any?, at path: [String], in data: Data) throws -> Data {
        guard !path.isEmpty else { return data }

        let root = try mutableRootObject(from: data)
        var current: NSMutableDictionary = root
        var currentPath: [String] = []
        for parent in path.dropLast() {
            currentPath.append(parent)
            if let existing = current[parent] {
                guard let existingDictionary = existing as? NSMutableDictionary else {
                    throw EditorError.parentIsNotJSONObject(path: currentPath)
                }
                current = existingDictionary
            } else {
                let new = NSMutableDictionary()
                current[parent] = new
                current = new
            }
        }

        guard let leaf = path.last else { return data }
        if let value {
            current[leaf] = value
        } else {
            current.removeObject(forKey: leaf)
        }

        // Codex App writes this file as a single-line minified JSON object.
        // We match that on output so the file's hash only changes for the
        // keys we actually touched and Codex App never re-pretty-prints on
        // its next quit.
        return try JSONSerialization.data(
            withJSONObject: root,
            options: [.withoutEscapingSlashes]
        )
    }

    private func mutableRootObject(from data: Data) throws -> NSMutableDictionary {
        guard !data.isEmpty else {
            return NSMutableDictionary()
        }
        let parsed = try JSONSerialization.jsonObject(
            with: data,
            options: [.mutableContainers, .mutableLeaves]
        )
        guard let dict = parsed as? NSMutableDictionary else {
            throw EditorError.notAJSONObject
        }
        return dict
    }
}
