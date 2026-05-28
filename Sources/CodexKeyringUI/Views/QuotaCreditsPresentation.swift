import SwiftUI
import CodexKeyringDomain

enum QuotaCreditsTint: Equatable {
    case secondary
    case depleted

    var color: Color {
        switch self {
        case .secondary:
            return .secondary
        case .depleted:
            return .red
        }
    }
}

struct QuotaCreditsPresentation: Equatable {
    let isVisible: Bool
    let label: String
    let systemImage: String
    let tint: QuotaCreditsTint

    init(credits: QuotaCredits) {
        isVisible = credits.hasCredits
        label = credits.unlimited ? "Credits: unlimited" : "Credits: \(credits.balance ?? "unknown")"
        systemImage = credits.isDepleted ? "creditcard.trianglebadge.exclamationmark" : "creditcard"
        tint = credits.isDepleted ? .depleted : .secondary
    }
}
