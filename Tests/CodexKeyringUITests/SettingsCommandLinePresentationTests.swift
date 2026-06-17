import XCTest
@testable import CodexKeyringUI

final class SettingsCommandLinePresentationTests: XCTestCase {
    func testSettingsCommandLinePresentationShowsShortCommand() {
        let presentation = SettingsCommandLinePresentation(
            installDestinationPath: "/Users/example/.local/bin/ckr"
        )

        XCTAssertEqual(presentation.command, "ckr status")
        XCTAssertEqual(presentation.installTitle, "Install ckr")
        XCTAssertEqual(presentation.uninstallTitle, "Uninstall")
        XCTAssertEqual(presentation.installDestinationPath, "/Users/example/.local/bin/ckr")
        XCTAssertTrue(presentation.note.contains("ckr --help"))
        XCTAssertFalse(presentation.note.contains("codex-keyring"))
    }
}
