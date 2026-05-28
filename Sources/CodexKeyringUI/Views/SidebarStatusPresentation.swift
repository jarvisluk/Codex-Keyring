import SwiftUI

enum SidebarStatusIndicator: Equatable {
    case error
    case busy
    case none

    var systemImage: String? {
        switch self {
        case .error:
            return "exclamationmark.triangle.fill"
        case .busy, .none:
            return nil
        }
    }
}

enum SidebarStatusTint: Equatable {
    case error
    case secondary

    var color: Color {
        switch self {
        case .error:
            return .red
        case .secondary:
            return .secondary
        }
    }
}

struct SidebarStatusPresentation: Equatable {
    let message: String
    let indicator: SidebarStatusIndicator
    let textTint: SidebarStatusTint
    let lineLimit: Int
    let help: String
    let accessibilityLabel: String

    init(statusMessage: String, lastError: String?, isBusy: Bool) {
        self.message = statusMessage
        self.help = statusMessage
        self.accessibilityLabel = "Status: \(statusMessage)"

        if lastError != nil {
            indicator = .error
            textTint = .error
            lineLimit = 3
        } else {
            indicator = isBusy ? .busy : .none
            textTint = .secondary
            lineLimit = 2
        }
    }
}
