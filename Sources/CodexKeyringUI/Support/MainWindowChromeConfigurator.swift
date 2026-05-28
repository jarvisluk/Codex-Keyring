import AppKit
import SwiftUI

struct MainWindowChromeConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> MainWindowChromeView {
        MainWindowChromeView()
    }

    func updateNSView(_ nsView: MainWindowChromeView, context: Context) {
        nsView.configureWindowChrome()
    }

    @MainActor
    static func configure(_ window: NSWindow?) {
        guard let window else { return }
        window.toolbarStyle = .unified
        window.titlebarSeparatorStyle = .none
    }
}

final class MainWindowChromeView: NSView {
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        configureWindowChrome()
    }

    func configureWindowChrome() {
        MainWindowChromeConfigurator.configure(window)
        DispatchQueue.main.async { [weak self] in
            MainWindowChromeConfigurator.configure(self?.window)
        }
    }
}
