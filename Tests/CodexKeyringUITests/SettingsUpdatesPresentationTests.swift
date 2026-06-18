import XCTest
@testable import CodexKeyringUI

final class SettingsUpdatesPresentationTests: XCTestCase {
    func testSettingsUpdatesPresentationEnablesControlsWhenConfigured() {
        let presentation = SettingsUpdatesPresentation(
            isConfigured: true,
            canCheckForUpdates: true,
            isAutomaticCheckEnabled: true,
            canAutomaticallyDownloadUpdates: true,
            isAutomaticDownloadEnabled: false
        )

        XCTAssertTrue(presentation.canCheckForUpdates)
        XCTAssertTrue(presentation.canToggleAutomaticChecks)
        XCTAssertTrue(presentation.canToggleAutomaticDownloads)
        XCTAssertTrue(presentation.note.contains("ask before installing"))
    }

    func testSettingsUpdatesPresentationDisablesControlsWhenUnconfigured() {
        let presentation = SettingsUpdatesPresentation(
            isConfigured: false,
            canCheckForUpdates: true,
            isAutomaticCheckEnabled: false,
            canAutomaticallyDownloadUpdates: true,
            isAutomaticDownloadEnabled: true
        )

        XCTAssertFalse(presentation.canCheckForUpdates)
        XCTAssertFalse(presentation.canToggleAutomaticChecks)
        XCTAssertFalse(presentation.canToggleAutomaticDownloads)
        XCTAssertTrue(presentation.note.contains("release builds"))
    }

    func testSettingsUpdatesPresentationKeepsManualCheckDisabledDuringUpdateSession() {
        let presentation = SettingsUpdatesPresentation(
            isConfigured: true,
            canCheckForUpdates: false,
            isAutomaticCheckEnabled: true,
            canAutomaticallyDownloadUpdates: true,
            isAutomaticDownloadEnabled: false
        )

        XCTAssertFalse(presentation.canCheckForUpdates)
        XCTAssertTrue(presentation.canToggleAutomaticChecks)
        XCTAssertTrue(presentation.canToggleAutomaticDownloads)
        XCTAssertTrue(presentation.note.contains("ask before installing"))
    }

    func testSettingsUpdatesPresentationDisablesAutomaticDownloadsWhenChecksAreOff() {
        let presentation = SettingsUpdatesPresentation(
            isConfigured: true,
            canCheckForUpdates: true,
            isAutomaticCheckEnabled: false,
            canAutomaticallyDownloadUpdates: true,
            isAutomaticDownloadEnabled: false
        )

        XCTAssertFalse(presentation.canToggleAutomaticDownloads)
        XCTAssertTrue(presentation.note.contains("off"))
    }

    func testSettingsUpdatesPresentationShowsAutomaticInstallState() {
        let presentation = SettingsUpdatesPresentation(
            isConfigured: true,
            canCheckForUpdates: true,
            isAutomaticCheckEnabled: true,
            canAutomaticallyDownloadUpdates: true,
            isAutomaticDownloadEnabled: true
        )

        XCTAssertTrue(presentation.canToggleAutomaticDownloads)
        XCTAssertTrue(presentation.note.contains("Automatic updates are enabled"))
    }
}
