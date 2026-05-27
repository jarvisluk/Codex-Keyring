import AppKit
import SwiftUI
import CodexKeyringUI

@MainActor
final class MainWindowController: NSObject, NSWindowDelegate {
    static let shared = MainWindowController()

    private var store: AccountStore?
    private var settingsPresentation: SettingsPresentationStore?
    private var mainWindow: NSWindow?

    func configure(store: AccountStore, settingsPresentation: SettingsPresentationStore) {
        self.store = store
        self.settingsPresentation = settingsPresentation
    }

    func show() {
        guard let store, let settingsPresentation else { return }
        if let mainWindow {
            if mainWindow.isMiniaturized {
                mainWindow.deminiaturize(nil)
            }
            mainWindow.makeKeyAndOrderFront(nil)
            mainWindow.orderFrontRegardless()
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let contentView = ContentView()
            .environmentObject(store)
            .environmentObject(settingsPresentation)
            .frame(minWidth: 920, minHeight: 600)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1040, height: 680),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.identifier = NSUserInterfaceItemIdentifier("main")
        window.title = "Codex Keyring"
        window.minSize = NSSize(width: 920, height: 600)
        window.isReleasedWhenClosed = false
        window.contentViewController = NSHostingController(rootView: contentView)
        window.delegate = self
        window.center()
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
        mainWindow = window
        NSApp.activate(ignoringOtherApps: true)
    }

    func windowWillClose(_ notification: Notification) {
        if notification.object as AnyObject? === mainWindow {
            mainWindow = nil
        }
    }
}
