import SwiftUI

private struct ContentViewCommandHandlers: ViewModifier {
    let startNewLogin: () -> Void
    let showAddCurrentLoginSheet: () -> Void
    let importAuthFile: () -> Void

    func body(content: Content) -> some View {
        content
            .onReceive(NotificationCenter.default.publisher(for: .codexKeyringStartNewLogin)) { _ in
                startNewLogin()
            }
            .onReceive(NotificationCenter.default.publisher(for: .codexKeyringShowAddCurrentLoginSheet)) { _ in
                showAddCurrentLoginSheet()
            }
            .onReceive(NotificationCenter.default.publisher(for: .codexKeyringImportAuthSnapshot)) { _ in
                importAuthFile()
            }
    }
}

extension View {
    func contentViewCommandHandlers(
        startNewLogin: @escaping () -> Void,
        showAddCurrentLoginSheet: @escaping () -> Void,
        importAuthFile: @escaping () -> Void
    ) -> some View {
        modifier(
            ContentViewCommandHandlers(
                startNewLogin: startNewLogin,
                showAddCurrentLoginSheet: showAddCurrentLoginSheet,
                importAuthFile: importAuthFile
            )
        )
    }
}
