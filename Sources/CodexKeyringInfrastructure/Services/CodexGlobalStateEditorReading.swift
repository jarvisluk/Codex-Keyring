import Foundation

extension CodexGlobalStateEditor {
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
}
