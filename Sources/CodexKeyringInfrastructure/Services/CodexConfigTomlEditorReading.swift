import Foundation

extension CodexConfigTomlEditor {
    /// Read a string value from the root table. Returns `nil` if the key is
    /// missing, lives inside a `[section]`, or has a non-string value.
    public func readString(_ key: String, in source: String) -> String? {
        for line in CodexConfigTomlLineParser.rootTableLines(of: source) {
            if let value = CodexConfigTomlLineParser.parseKeyValueString(line: line, expectedKey: key) {
                return value
            }
        }
        return nil
    }

    /// Read a boolean value from the root table. Returns `nil` if absent or
    /// not a boolean literal.
    public func readBool(_ key: String, in source: String) -> Bool? {
        for line in CodexConfigTomlLineParser.rootTableLines(of: source) {
            if let value = CodexConfigTomlLineParser.parseKeyValueBool(line: line, expectedKey: key) {
                return value
            }
        }
        return nil
    }
}
