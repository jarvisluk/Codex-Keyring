import AppKit
import SwiftUI

@MainActor
public enum MainWindowPresenter {
    public static let windowID = "main"
    public static let windowTitle = "Codex Keyring"

    public static func open(using openWindow: OpenWindowAction) {
        if let existingWindow = existingManagerWindow {
            if existingWindow.isMiniaturized {
                existingWindow.deminiaturize(nil)
            }
            existingWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        openWindow(id: windowID)
        NSApp.activate(ignoringOtherApps: true)
    }

    static func isManagerWindow(identifier: String?, title: String) -> Bool {
        identifier == windowID || title == windowTitle
    }

    private static var existingManagerWindow: NSWindow? {
        NSApp.windows.first { window in
            isManagerWindow(identifier: window.identifier?.rawValue, title: window.title)
        }
    }
}
