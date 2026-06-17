import CodexKeyringDomain
import Foundation

struct AccountSelectorCandidate: Equatable, Sendable {
    var id: UUID
    var displayName: String
    var email: String
}

enum AccountSelectorError: LocalizedError, Equatable {
    case empty
    case notFound(String)
    case ambiguous(String, [AccountSelectorCandidate])

    var errorDescription: String? {
        switch self {
        case .empty:
            return "Account selector cannot be empty."
        case .notFound(let selector):
            return "No saved account matches '\(selector)'."
        case .ambiguous(let selector, let candidates):
            let labels = candidates
                .map { "\($0.displayName) <\($0.email)> (\($0.id.uuidString))" }
                .joined(separator: ", ")
            return "Account selector '\(selector)' is ambiguous: \(labels)"
        }
    }
}

struct AccountSelector {
    func resolve(_ rawSelector: String, accounts: [CodexAccount]) throws -> CodexAccount {
        let selector = rawSelector.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !selector.isEmpty else {
            throw AccountSelectorError.empty
        }

        if let uuid = UUID(uuidString: selector),
           let exact = accounts.first(where: { $0.id == uuid }) {
            return exact
        }

        let lowered = selector.lowercased()
        let exactMatches = accounts.filter { account in
            account.alias.lowercased() == lowered
                || account.email.lowercased() == lowered
                || account.accountIdentifier.lowercased() == lowered
        }
        if let match = try unique(exactMatches, selector: selector) {
            return match
        }

        let prefixMatches = accounts.filter { account in
            account.id.uuidString.lowercased().hasPrefix(lowered)
                || account.fingerprint.lowercased().hasPrefix(lowered)
        }
        if let match = try unique(prefixMatches, selector: selector) {
            return match
        }

        throw AccountSelectorError.notFound(selector)
    }

    private func unique(_ matches: [CodexAccount], selector: String) throws -> CodexAccount? {
        guard !matches.isEmpty else { return nil }
        guard matches.count == 1, let match = matches.first else {
            throw AccountSelectorError.ambiguous(
                selector,
                matches.map {
                    AccountSelectorCandidate(
                        id: $0.id,
                        displayName: $0.displayName,
                        email: $0.displayEmail
                    )
                }
            )
        }
        return match
    }
}
