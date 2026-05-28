import SwiftUI
import CodexKeyringDomain

enum SidebarAccountTint: Equatable {
    case primary
    case secondary
    case active
    case selectedPrimary
    case selectedSecondary
    case quotaHealth(QuotaHealth)

    var color: Color {
        switch self {
        case .primary:
            return .primary
        case .secondary:
            return .secondary
        case .active:
            return .green
        case .selectedPrimary:
            return .white
        case .selectedSecondary:
            return .white.opacity(0.82)
        case let .quotaHealth(health):
            return health.tint
        }
    }
}
