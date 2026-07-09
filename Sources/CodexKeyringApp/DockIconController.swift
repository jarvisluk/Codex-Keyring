import AppKit

@MainActor
enum DockIconController {
    private static var wantsDockIcon = true
    private static var windowObservers: [NSObjectProtocol] = []

    static func apply(showDockIcon: Bool) {
        wantsDockIcon = showDockIcon
        installWindowObserversIfNeeded()
        updateActivationPolicy()
    }

    private static func updateActivationPolicy() {
        let visibleWindows = VisibleWindowSnapshot()
        let shouldUseRegularPolicy = wantsDockIcon || !visibleWindows.windows.isEmpty
        let policy: NSApplication.ActivationPolicy = shouldUseRegularPolicy ? .regular : .accessory
        guard NSApp.activationPolicy() != policy else { return }
        NSApp.setActivationPolicy(policy)
        guard shouldUseRegularPolicy else { return }
        Task { @MainActor in
            restore(visibleWindows)
        }
    }

    private static func restore(_ snapshot: VisibleWindowSnapshot) {
        guard !snapshot.windows.isEmpty else { return }
        NSApp.unhide(nil)
        for window in snapshot.windows.reversed() {
            window.orderFrontRegardless()
        }
        if let keyWindow = snapshot.keyWindow, snapshot.windows.contains(keyWindow) {
            keyWindow.makeKeyAndOrderFront(nil)
        } else {
            snapshot.windows.first?.makeKeyAndOrderFront(nil)
        }
        NSApp.activate(ignoringOtherApps: true)
    }

    private static func installWindowObserversIfNeeded() {
        guard windowObservers.isEmpty else { return }
        let names: [Notification.Name] = [
            NSWindow.didBecomeKeyNotification,
            NSWindow.didBecomeMainNotification,
            NSWindow.didDeminiaturizeNotification,
            NSWindow.didMiniaturizeNotification,
            NSWindow.didResignKeyNotification,
            NSWindow.willCloseNotification
        ]
        let center = NotificationCenter.default
        windowObservers = names.map { name in
            center.addObserver(
                forName: name,
                object: nil,
                queue: .main
            ) { _ in
                Task { @MainActor in
                    await Task.yield()
                    updateActivationPolicy()
                }
            }
        }
    }
}

@MainActor
private struct VisibleWindowSnapshot {
    let windows: [NSWindow]
    let keyWindow: NSWindow?

    init() {
        windows = NSApp.orderedWindows.filter { window in
            window.isVisible
                && !window.isMiniaturized
                && (window.canBecomeKey || window.canBecomeMain)
        }
        keyWindow = NSApp.keyWindow
    }
}
