import Foundation
import CodexKeyringDomain

extension AccountQuotaState {
    var compactSidebarSummary: String? {
        if phase == .loading { return "quota refreshing" }
        guard let bucket = snapshot?.primaryBucket else {
            return fallbackSummary
        }
        return bucket.compactSidebarLimitSummary ?? fallbackSummary
    }

    var sidebarSummary: String? {
        if phase == .loading { return "quota refreshing" }
        guard let bucket = snapshot?.primaryBucket else {
            return fallbackSummary
        }
        return bucket.compactLimitSummary ?? fallbackSummary
    }

    private var fallbackSummary: String? {
        switch phase {
        case .error:
            return "quota unavailable"
        case .unsupported:
            return "quota unsupported"
        case .idle, .available, .loading:
            return nil
        }
    }

    var menuSummary: String? {
        if phase == .loading { return "checking" }
        if snapshot?.primaryBucket?.isUnlimited == true {
            return "unlimited"
        }
        if let remaining = snapshot?.primaryBucket?.remainingPercent {
            return "\(Int(remaining.rounded()))% left"
        }
        switch phase {
        case .error:
            return "quota error"
        case .unsupported:
            return "unsupported"
        case .idle, .available, .loading:
            return nil
        }
    }

    var menuDetailSummary: String? {
        menuDetailSummary(now: Date())
    }

    func menuDetailSummary(now: Date) -> String? {
        if phase == .loading { return "checking quotas" }
        guard let bucket = snapshot?.primaryBucket else {
            return resetCreditMenuSummary(now: now) ?? menuSummary
        }
        let summary = bucket.compactLimitSummary ?? menuSummary
        let resetSummary = resetCreditMenuSummary(now: now)
        let combined = [summary, resetSummary]
            .compactMap { $0 }
            .joined(separator: " · ")
        return combined.isEmpty ? nil : combined.cappedMenuBarText
    }

    private func resetCreditMenuSummary(now: Date) -> String? {
        snapshot?.rateLimitResetCredits?.compactMenuSummary(now: now)
    }
}
