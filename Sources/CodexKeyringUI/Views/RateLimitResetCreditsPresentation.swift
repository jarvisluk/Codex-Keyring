import Foundation
import CodexKeyringDomain

struct RateLimitResetCreditsPresentation: Equatable {
    let isVisible: Bool
    let summaryText: String
    let expirationText: String
    let exactExpirationText: String?
    let rows: [RateLimitResetCreditRowPresentation]

    init(resetCredits: AccountRateLimitResetCredits, now: Date = Date()) {
        let availableCount = resetCredits.visibleAvailableCount
        isVisible = availableCount > 0
        summaryText = availableCount == 1 ? "1 reset available" : "\(availableCount) resets available"

        if let nextExpiration = resetCredits.nextExpirationDate {
            let remaining = RateLimitResetCreditTimeFormatter.compactRemaining(
                until: nextExpiration,
                now: now
            )
            expirationText = nextExpiration <= now
                ? "Earliest reset credit expired"
                : "Earliest expires in \(remaining)"
            exactExpirationText = "Expires \(nextExpiration.formatted(date: .abbreviated, time: .shortened))"
        } else {
            expirationText = "Expiration unavailable"
            exactExpirationText = nil
        }

        rows = resetCredits.availableCredits.enumerated().map { index, credit in
            RateLimitResetCreditRowPresentation(
                credit: credit,
                index: index,
                now: now
            )
        }
    }
}

struct RateLimitResetCreditRowPresentation: Equatable, Identifiable {
    let id: String
    let title: String
    let expirationText: String
    let exactExpirationText: String?

    init(credit: RateLimitResetCredit, index: Int, now: Date = Date()) {
        id = credit.id
        title = Self.displayTitle(for: credit, fallbackIndex: index)

        if let expiresAt = credit.expiresAt {
            let remaining = RateLimitResetCreditTimeFormatter.compactRemaining(
                until: expiresAt,
                now: now
            )
            expirationText = expiresAt <= now ? "expired" : remaining
            exactExpirationText = expiresAt.formatted(date: .abbreviated, time: .shortened)
        } else {
            expirationText = "unknown"
            exactExpirationText = nil
        }
    }

    private static func displayTitle(for credit: RateLimitResetCredit, fallbackIndex: Int) -> String {
        guard let title = credit.title?.trimmingCharacters(in: .whitespacesAndNewlines),
              !title.isEmpty
        else {
            return "Reset credit \(fallbackIndex + 1)"
        }
        return title
    }
}

enum RateLimitResetCreditTimeFormatter {
    static func compactRemaining(until date: Date, now: Date) -> String {
        let seconds = max(0, Int(ceil(date.timeIntervalSince(now))))
        guard seconds >= 60 else { return "<1m" }

        let days = seconds / 86_400
        let hours = (seconds % 86_400) / 3_600
        let minutes = (seconds % 3_600) / 60

        if days > 0 {
            return hours > 0 ? "\(days)d \(hours)h" : "\(days)d"
        }
        if hours > 0 {
            return minutes > 0 ? "\(hours)h \(minutes)m" : "\(hours)h"
        }
        return "\(minutes)m"
    }
}

extension AccountRateLimitResetCredits {
    func compactMenuSummary(now: Date = Date()) -> String? {
        guard hasAvailableCredits else { return nil }
        guard let nextExpirationDate else {
            return "reset expiry unknown"
        }
        let remaining = RateLimitResetCreditTimeFormatter.compactRemaining(
            until: nextExpirationDate,
            now: now
        )
        return "reset \(remaining)"
    }
}
