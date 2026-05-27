import Foundation

/// Read / write a single JSON value at a dotted key path inside
/// `~/.codex/.codex-global-state.json`, preserving every other key, value and
/// key order.
///
/// We use `JSONSerialization` (not `JSONEncoder`) so the round-trip keeps
/// `NSMutableDictionary`'s insertion order. We then re-serialize WITHOUT
/// `.sortedKeys` so Codex App still sees its own key order on next launch.
public struct CodexGlobalStateEditor: Sendable {
    public init() {}

    /// Read a string at the given dotted path, e.g.
    /// `["electron-persisted-atom-state", "agent-mode-by-host-id", "local"]`.
    public func readString(at path: [String], in data: Data) -> String? {
        readRaw(at: path, in: data) as? String
    }

    public func readBool(at path: [String], in data: Data) -> Bool? {
        // NSNumber bridges to Bool only when the underlying CFNumber is a
        // boolean; integers like 0/1 from JSONSerialization do NOT bridge.
        if let number = readRaw(at: path, in: data) as? NSNumber,
           CFGetTypeID(number) == CFBooleanGetTypeID() {
            return number.boolValue
        }
        return nil
    }

    public func readStringArray(at path: [String], in data: Data) -> [String]? {
        guard let raw = readRaw(at: path, in: data) as? [Any] else { return nil }
        var strings: [String] = []
        strings.reserveCapacity(raw.count)
        for item in raw {
            guard let string = item as? String else { return nil }
            strings.append(string)
        }
        return strings
    }

    /// Write `value` at the given dotted path, creating any missing parent
    /// dictionaries. Returns the updated JSON bytes. `value == nil` removes
    /// the leaf key (and does NOT clean up newly-empty parents).
    public func writing(_ value: Any?, at path: [String], in data: Data) throws -> Data {
        guard !path.isEmpty else { return data }

        let root: NSMutableDictionary
        if data.isEmpty {
            root = NSMutableDictionary()
        } else {
            let parsed = try JSONSerialization.jsonObject(
                with: data,
                options: [.mutableContainers, .mutableLeaves]
            )
            guard let dict = parsed as? NSMutableDictionary else {
                throw EditorError.notAJSONObject
            }
            root = dict
        }

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

    private func readRaw(at path: [String], in data: Data) -> Any? {
        guard !path.isEmpty, !data.isEmpty else { return nil }
        guard let parsed = try? JSONSerialization.jsonObject(with: data, options: []) else {
            return nil
        }
        var cursor: Any = parsed
        for key in path {
            guard let dict = cursor as? [String: Any], let next = dict[key] else { return nil }
            cursor = next
        }
        return cursor
    }

    public enum EditorError: Error, Equatable, LocalizedError {
        case notAJSONObject
        case parentIsNotJSONObject(path: [String])

        public var errorDescription: String? {
            switch self {
            case .notAJSONObject:
                return "Expected global-state JSON root to be an object."
            case .parentIsNotJSONObject(let path):
                let location = path.joined(separator: ".")
                return "Expected JSON object at \(location) before writing global-state value."
            }
        }
    }
}
