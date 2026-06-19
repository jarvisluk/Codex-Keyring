import CodexKeyringDomain

enum AccountSensitiveText {
    static func display(_ value: String, revealed: Bool) -> String {
        guard !revealed else { return value }

        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard shouldMask(trimmed) else { return value }

        if let maskedEmail = maskedEmail(trimmed) {
            return maskedEmail
        }
        return maskedGeneric(trimmed)
    }

    static func displayName(for account: CodexAccount, revealed: Bool) -> String {
        let alias = account.alias.trimmingCharacters(in: .whitespacesAndNewlines)
        guard alias.isEmpty else { return alias }
        return display(account.displayEmail, revealed: revealed)
    }

    static func displayEmail(for account: CodexAccount, revealed: Bool) -> String {
        display(account.displayEmail, revealed: revealed)
    }

    private static func shouldMask(_ value: String) -> Bool {
        guard !value.isEmpty else { return false }
        switch value {
        case "Unknown", "Unknown email", "No readable auth.json":
            return false
        default:
            return true
        }
    }

    private static func maskedEmail(_ value: String) -> String? {
        let parts = value.split(separator: "@", maxSplits: 1, omittingEmptySubsequences: false)
        guard parts.count == 2, !parts[0].isEmpty, !parts[1].isEmpty else {
            return nil
        }

        return "\(maskedEmailLocal(String(parts[0])))@\(maskedEmailDomain(String(parts[1])))"
    }

    private static func maskedEmailLocal(_ value: String) -> String {
        let characters = Array(value)
        switch characters.count {
        case 0:
            return value
        case 1:
            return "*"
        default:
            return String(characters.prefix(2)) + "****"
        }
    }

    private static func maskedEmailDomain(_ value: String) -> String {
        let labels = value.split(separator: ".", omittingEmptySubsequences: false)
        guard labels.count > 1 else {
            return maskedEmailDomainLabel(value)
        }

        let maskedLabels = labels.enumerated().map { index, label in
            if index == labels.count - 1 {
                return String(label)
            }
            return maskedEmailDomainLabel(String(label))
        }
        return maskedLabels.joined(separator: ".")
    }

    private static func maskedEmailDomainLabel(_ value: String) -> String {
        guard let first = value.first else { return value }
        return "\(first)****"
    }

    private static func maskedGeneric(_ value: String) -> String {
        let characters = Array(value)
        switch characters.count {
        case 0:
            return value
        case 1:
            return "*"
        case 2:
            return "\(characters[0])*"
        case 3...4:
            return String(characters.prefix(1)) + "****" + String(characters.suffix(1))
        case 5...8:
            return String(characters.prefix(2)) + "****" + String(characters.suffix(2))
        default:
            return String(characters.prefix(4)) + "****" + String(characters.suffix(4))
        }
    }
}
