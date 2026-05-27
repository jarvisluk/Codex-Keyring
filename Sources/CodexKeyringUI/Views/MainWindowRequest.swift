import Foundation

public extension Notification.Name {
    static let codexKeyringShowMainWindow = Notification.Name("CodexKeyringShowMainWindow")
    static let codexKeyringStartNewLogin = Notification.Name("CodexKeyringStartNewLogin")
    static let codexKeyringShowAddCurrentLoginSheet = Notification.Name("CodexKeyringShowAddCurrentLoginSheet")
}

public enum MainWindowRequest {
    public static func showMainWindow(notificationCenter: NotificationCenter = .default) {
        notificationCenter.post(name: .codexKeyringShowMainWindow, object: nil)
    }

    public static func startNewLogin(notificationCenter: NotificationCenter = .default) {
        notificationCenter.post(name: .codexKeyringStartNewLogin, object: nil)
    }

    public static func showAddCurrentLoginSheet(notificationCenter: NotificationCenter = .default) {
        notificationCenter.post(name: .codexKeyringShowAddCurrentLoginSheet, object: nil)
    }

    public static func runAfterCurrentMainActorTurn(
        _ action: @escaping @MainActor @Sendable () -> Void
    ) {
        Task { @MainActor in
            await Task.yield()
            action()
        }
    }
}
