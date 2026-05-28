import AppKit
import SwiftUI

struct MenuBarAppActionsSection: View {
    @Environment(\.openWindow) private var openWindow
    @EnvironmentObject private var settingsPresentation: SettingsPresentationStore

    var body: some View {
        Button("Settings") {
            MenuBarWindowActions.openManager(using: openWindow)
            settingsPresentation.present()
        }

        Button("Quit") {
            NSApp.terminate(nil)
        }
    }
}
