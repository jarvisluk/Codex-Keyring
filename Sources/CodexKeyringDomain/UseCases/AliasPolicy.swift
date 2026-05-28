import Foundation

/// Pure rules for alias suggestion, sanitization, and uniqueness.
/// No IO; safe to use from any thread.
public struct AliasPolicy: Sendable {
    public init() {}

    /// Trim whitespace; fall back to `fallback` when result is empty.
    public func clean(_ alias: String?, fallback: String) -> String {
        let cleaned = (alias ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let fallback = fallback.trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? (fallback.isEmpty ? "account" : fallback) : cleaned
    }

    /// Trim whitespace while preserving an intentionally empty alias.
    public func cleanAllowingEmpty(_ alias: String) -> String {
        alias.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Suggest a default alias from auth metadata, preferring the email local part.
    public func suggested(for metadata: AuthMetadata) -> String {
        let email = metadata.email.trimmingCharacters(in: .whitespacesAndNewlines)
        if email.contains("@"),
           let local = email.components(separatedBy: "@").first?.trimmingCharacters(in: .whitespacesAndNewlines),
           !local.isEmpty {
            return local
        }
        return email.isEmpty ? "account" : email
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

    public func uniquified(
        _ alias: String,
        among accounts: some Sequence<CodexAccount>,
        excluding excludedAccountID: UUID? = nil
    ) -> String {
        let aliases = accounts.lazy.compactMap { account in
            account.id == excludedAccountID ? nil : account.alias
        }
        return uniquified(alias, existingAliases: aliases)
    }

    public func renameAlias(
        _ alias: String,
        for account: CodexAccount,
        among accounts: some Sequence<CodexAccount>
    ) -> String {
        let cleaned = cleanAllowingEmpty(alias)
        guard !cleaned.isEmpty else { return cleaned }
        return uniquified(cleaned, among: accounts, excluding: account.id)
    }
}
