import Foundation

public extension Notification.Name {
    static let codexKeyringStartNewLogin = Notification.Name("CodexKeyringStartNewLogin")
    static let codexKeyringShowAddCurrentLoginSheet = Notification.Name("CodexKeyringShowAddCurrentLoginSheet")
    static let codexKeyringImportAuthSnapshot = Notification.Name("CodexKeyringImportAuthSnapshot")
}

public enum MainWindowRequest {
    public static func startNewLogin(notificationCenter: NotificationCenter = .default) {
        notificationCenter.post(name: .codexKeyringStartNewLogin, object: nil)
    }

    public static func showAddCurrentLoginSheet(notificationCenter: NotificationCenter = .default) {
        notificationCenter.post(name: .codexKeyringShowAddCurrentLoginSheet, object: nil)
    }

    public static func importAuthSnapshot(notificationCenter: NotificationCenter = .default) {
        notificationCenter.post(name: .codexKeyringImportAuthSnapshot, object: nil)
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
