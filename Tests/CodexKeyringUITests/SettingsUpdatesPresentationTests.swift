import XCTest
@testable import CodexKeyringUI

final class SettingsUpdatesPresentationTests: XCTestCase {
    func testSettingsUpdatesPresentationEnablesControlsWhenConfigured() {
        let presentation = SettingsUpdatesPresentation(
            isConfigured: true,
            canCheckForUpdates: true,
            isAutomaticCheckEnabled: true
        )

        XCTAssertTrue(presentation.canCheckForUpdates)
        XCTAssertTrue(presentation.canToggleAutomaticChecks)
        XCTAssertTrue(presentation.note.contains("enabled"))
    }

    func testSettingsUpdatesPresentationDisablesControlsWhenUnconfigured() {
        let presentation = SettingsUpdatesPresentation(
            isConfigured: false,
            canCheckForUpdates: true,
            isAutomaticCheckEnabled: false
        )

        XCTAssertFalse(presentation.canCheckForUpdates)
        XCTAssertFalse(presentation.canToggleAutomaticChecks)
        XCTAssertTrue(presentation.note.contains("release builds"))
    }

    func testSettingsUpdatesPresentationKeepsManualCheckDisabledDuringUpdateSession() {
        let presentation = SettingsUpdatesPresentation(
            isConfigured: true,
            canCheckForUpdates: false,
            isAutomaticCheckEnabled: false
        )

        XCTAssertFalse(presentation.canCheckForUpdates)
        XCTAssertTrue(presentation.canToggleAutomaticChecks)
        XCTAssertTrue(presentation.note.contains("off"))
    }
}
