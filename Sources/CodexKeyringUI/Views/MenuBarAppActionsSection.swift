import AppKit
import SwiftUI

struct MenuBarAppActionsSection: View {
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        Button("Settings") {
            openSettings()
        }

        Button("Quit") {
            NSApp.terminate(nil)
        }
    }
}
