import SwiftUI
import CodexKeyringDomain

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
