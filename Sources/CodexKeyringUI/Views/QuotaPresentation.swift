import SwiftUI
import CodexKeyringDomain

extension AccountQuotaState {
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
        if phase == .loading { return "checking quotas" }
        guard let bucket = snapshot?.primaryBucket else {
            return menuSummary
        }
        return bucket.compactLimitSummary?.cappedMenuBarText ?? menuSummary
    }
}

extension QuotaHealth {
    var tint: Color {
        switch self {
        case .ready:
            return .green
        case .watch:
            return .yellow
        case .low:
            return .orange
        case .blocked, .error:
            return .red
        case .unsupported:
            return .secondary
        }
    }

    var systemImage: String {
        switch self {
        case .ready:
            return "checkmark.circle.fill"
        case .watch:
            return "gauge.medium"
        case .low:
            return "exclamationmark.triangle.fill"
        case .blocked:
            return "xmark.octagon.fill"
        case .error:
            return "exclamationmark.circle.fill"
        case .unsupported:
            return "minus.circle"
        }
    }

    var label: String {
        switch self {
        case .ready:
            return "Ready"
        case .watch:
            return "Watch"
        case .low:
            return "Low"
        case .blocked:
            return "Blocked"
        case .error:
            return "Error"
        case .unsupported:
            return "Unsupported"
        }
    }
}

extension QuotaWindow {
    var formattedRemaining: String {
        "\(Int(remainingPercent.rounded()))%"
    }

    var compactDurationLabel: String {
        guard let minutes = windowDurationMinutes else { return "limit" }
        switch minutes {
        case 5 * 60:
            return "5h"
        case 7 * 24 * 60:
            return "week"
        default:
            return durationLabel.lowercased()
        }
    }

    var formattedReset: String {
        guard let resetsAt else { return "reset unknown" }
        if resetsAt <= Date() {
            return "resets now"
        }
        let relative = resetsAt.formatted(.relative(presentation: .numeric))
        return "resets \(relative)"
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

private extension QuotaBucket {
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
