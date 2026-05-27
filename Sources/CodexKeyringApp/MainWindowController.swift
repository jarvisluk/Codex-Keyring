import AppKit
import SwiftUI
import CodexKeyringUI

@MainActor
final class MainWindowController: NSObject, NSWindowDelegate {
    static let shared = MainWindowController()

    private var store: AccountStore?
    private var mainWindow: NSWindow?
    private var isObserving = false

    func configure(store: AccountStore) {
        self.store = store
        guard !isObserving else { return }
        isObserving = true
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleShowMainWindowRequest),
            name: .codexKeyringShowMainWindow,
            object: nil
        )
    }

    func show() {
        guard let store else { return }
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

    func showAddCurrentLoginSheet() {
        show()
        MainWindowRequest.runAfterCurrentMainActorTurn {
            MainWindowRequest.showAddCurrentLoginSheet()
        }
    }

    func showAddNewLoginFlow() {
        show()
        MainWindowRequest.runAfterCurrentMainActorTurn {
            MainWindowRequest.startNewLogin()
        }
    }

    func showImportAuthSnapshotPanel() {
        guard let store else { return }
        show()
        MainWindowRequest.runAfterCurrentMainActorTurn {
            AuthImportPanel.chooseAndImport(using: store)
        }
    }

    func windowWillClose(_ notification: Notification) {
        if notification.object as AnyObject? === mainWindow {
            mainWindow = nil
        }
    }

    @objc private func handleShowMainWindowRequest() {
        show()
    }
}
