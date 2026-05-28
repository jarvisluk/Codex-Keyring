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
}
