import SwiftUI

enum MenuBarWindowActions {
    @MainActor
    static func openManager(using openWindow: OpenWindowAction) {
        MainWindowPresenter.open(using: openWindow)
    }

    @MainActor
    static func openManagerAndRun(
        using openWindow: OpenWindowAction,
        _ action: @escaping @MainActor () -> Void
    ) {
        openManager(using: openWindow)
        MainWindowRequest.runAfterCurrentMainActorTurn(action)
    }
}
