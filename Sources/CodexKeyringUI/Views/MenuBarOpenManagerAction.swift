import SwiftUI

struct MenuBarOpenManagerAction: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button("Open Manager") {
            MenuBarWindowActions.openManager(using: openWindow)
        }
    }
}
