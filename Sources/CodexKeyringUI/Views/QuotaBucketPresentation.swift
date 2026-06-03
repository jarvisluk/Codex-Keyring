import CodexKeyringDomain

extension QuotaBucket {
    var compactSidebarLimitSummary: String? {
        if isUnlimited {
            return "unlimited"
        }

        let parts = windows
            .sortedForMenuSummary()
            .prefix(2)
            .map { "\($0.compactDurationLabel) \($0.formattedRemaining)" }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    var compactLimitSummary: String? {
        if isUnlimited {
            return "5h unlimited · week unlimited"
        }

        let parts = windows
            .sortedForMenuSummary()
            .prefix(2)
            .map { "\($0.compactDurationLabel) \($0.formattedRemaining) left" }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}

private extension Array where Element == QuotaWindow {
    func sortedForMenuSummary() -> [QuotaWindow] {
        let preferredDurations = [5 * 60, 7 * 24 * 60]
        let preferred = preferredDurations.compactMap { duration in
            first { $0.windowDurationMinutes == duration }
        }
        let remaining = filter { window in
            guard let duration = window.windowDurationMinutes else { return true }
            return !preferredDurations.contains(duration)
        }
        return preferred + remaining
    }
}
