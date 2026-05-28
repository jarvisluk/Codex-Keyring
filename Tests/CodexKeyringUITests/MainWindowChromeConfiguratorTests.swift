import AppKit
import XCTest
@testable import CodexKeyringUI

final class MainWindowChromeConfiguratorTests: XCTestCase {
    @MainActor
    func testConfiguratorRemovesTitlebarSeparator() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 640, height: 480),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.titlebarSeparatorStyle = .line
        window.toolbarStyle = .expanded

        MainWindowChromeConfigurator.configure(window)

        XCTAssertEqual(window.titlebarSeparatorStyle, .none)
        XCTAssertEqual(window.toolbarStyle, .unified)
    }
}
