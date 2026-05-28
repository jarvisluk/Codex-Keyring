import CodexKeyringDomain

struct SidebarAccountPresentation: Equatable {
    let title: String
    let subtitle: String
    let quotaSummary: String?
    let accessibilitySummary: String
    let statusSystemImage: String
    let statusIconTint: SidebarAccountTint
    let titleTint: SidebarAccountTint
    let secondaryTextTint: SidebarAccountTint
    let quotaTextTint: SidebarAccountTint

    init(
        account: CodexAccount,
        isActive: Bool,
        isSelected: Bool = false,
        quotaState: AccountQuotaState?
    ) {
        self.title = account.displayName
        self.subtitle = account.displayEmail
        self.quotaSummary = quotaState?.sidebarSummary
        self.statusSystemImage = isActive ? "checkmark.circle.fill" : "person.crop.circle"
        self.statusIconTint = Self.statusIconTint(isActive: isActive, isSelected: isSelected)
        self.titleTint = isSelected ? .selectedPrimary : .primary
        self.secondaryTextTint = isSelected ? .selectedSecondary : .secondary
        self.quotaTextTint = Self.quotaTextTint(isSelected: isSelected, quotaState: quotaState)

        var accessibilityParts = [title, subtitle]
        if isActive {
            accessibilityParts.append("active")
        }
        if let quotaSummary {
            accessibilityParts.append(quotaSummary)
        }
        self.accessibilitySummary = accessibilityParts.joined(separator: ", ")
    }

    private static func statusIconTint(isActive: Bool, isSelected: Bool) -> SidebarAccountTint {
        if isSelected {
            return isActive ? .selectedPrimary : .selectedSecondary
        }
        return isActive ? .active : .secondary
    }

    private static func quotaTextTint(
        isSelected: Bool,
        quotaState: AccountQuotaState?
    ) -> SidebarAccountTint {
        if isSelected {
            return .selectedPrimary
        }
        guard let quotaState else {
            return .secondary
        }
        return .quotaHealth(quotaState.health)
    }
}
