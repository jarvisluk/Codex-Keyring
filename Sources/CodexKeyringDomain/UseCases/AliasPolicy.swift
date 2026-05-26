import Foundation

/// Pure rules for alias suggestion, sanitization, and uniqueness.
/// No IO; safe to use from any thread.
public struct AliasPolicy: Sendable {
    public init() {}

    /// Trim whitespace; fall back to `fallback` when result is empty.
    public func clean(_ alias: String?, fallback: String) -> String {
        let cleaned = (alias ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? fallback : cleaned
    }

    /// Suggest a default alias from auth metadata, preferring the email local part.
    public func suggested(for metadata: AuthMetadata) -> String {
        if metadata.email.contains("@"),
           let local = metadata.email.components(separatedBy: "@").first,
           !local.isEmpty {
            return local
        }
        return metadata.email.isEmpty ? "account" : metadata.email
    }

    /// Append `-2`, `-3`, ... when alias collides with an existing one (case-insensitive).
    /// Comparison is against `existingAliases`. The caller should exclude the alias being renamed.
    public func uniquified(_ alias: String, existingAliases: some Sequence<String>) -> String {
        let existing = Set(existingAliases.map { $0.lowercased() })
        guard existing.contains(alias.lowercased()) else {
            return alias
        }
        var index = 2
        while existing.contains("\(alias)-\(index)".lowercased()) {
            index += 1
        }
        return "\(alias)-\(index)"
    }
}
