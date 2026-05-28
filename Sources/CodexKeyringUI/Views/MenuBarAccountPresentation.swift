import SwiftUI
import CodexKeyringDomain

enum MenuBarAccountTint: Equatable {
    case active
    case secondary

    var color: Color {
        switch self {
        case .active:
            return .green
        case .secondary:
            return .secondary
        }
    }
}

struct MenuBarAccountPresentation: Equatable {
    let title: String
    let statusSystemImage: String
    let statusIconTint: MenuBarAccountTint
    let canSwitch: Bool

    init(account: CodexAccount, isActive: Bool = false, canSwitch: Bool = true) {
        title = account.displayName.cappedMenuBarText
        statusSystemImage = isActive ? "checkmark.circle.fill" : "person.crop.circle"
        statusIconTint = isActive ? .active : .secondary
        self.canSwitch = canSwitch
    }
}
