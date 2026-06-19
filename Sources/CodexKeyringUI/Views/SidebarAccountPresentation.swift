import CodexKeyringDomain

struct SidebarAccountPresentation: Equatable {
    let title: String
    let detailSummary: String?
    let detailAccessibilitySummary: String?
    let accessibilitySummary: String
    let statusSystemImage: String
    let statusIconTint: SidebarAccountTint
    let titleTint: SidebarAccountTint
    let quotaTextTint: SidebarAccountTint

    init(
        account: CodexAccount,
        isActive: Bool,
        isSelected: Bool = false,
        quotaState: AccountQuotaState?
    ) {
        self.title = Self.title(for: account)
        let planSummary = Self.planSummary(for: account)
        let quotaSummary = quotaState?.compactSidebarSummary
        let quotaAccessibilitySummary = quotaState?.sidebarSummary
        self.detailSummary = Self.joinedDetailSummary([
            planSummary,
            quotaSummary
        ])
        self.detailAccessibilitySummary = Self.joinedDetailSummary([
            planSummary,
            quotaAccessibilitySummary
        ])
        self.statusSystemImage = isActive ? "checkmark.circle.fill" : "person.crop.circle"
        self.statusIconTint = Self.statusIconTint(isActive: isActive, isSelected: isSelected)
        self.titleTint = isSelected ? .selectedPrimary : .primary
        self.quotaTextTint = Self.quotaTextTint(isSelected: isSelected, quotaState: quotaState)

        var accessibilityParts = [title]
        if isActive {
            accessibilityParts.append("active")
        }
        if let detailAccessibilitySummary {
            accessibilityParts.append(detailAccessibilitySummary)
        }
        self.accessibilitySummary = accessibilityParts.joined(separator: ", ")
    }

    private static func title(for account: CodexAccount) -> String {
        let alias = account.alias.trimmingCharacters(in: .whitespacesAndNewlines)
        return alias.isEmpty ? "Unnamed account" : alias
    }

    private static func planSummary(for account: CodexAccount) -> String? {
        let plan = account.plan.trimmingCharacters(in: .whitespacesAndNewlines)
        return plan.isEmpty ? nil : plan
    }

    private static func joinedDetailSummary(_ parts: [String?]) -> String? {
        let displayParts = parts.compactMap { part -> String? in
            guard let trimmed = part?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !trimmed.isEmpty
            else {
                return nil
            }
            return trimmed
        }
        return displayParts.isEmpty ? nil : displayParts.joined(separator: " - ")
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
