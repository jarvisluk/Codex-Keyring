import XCTest
@testable import CodexKeyringUI

final class SettingsLogsPresentationTests: XCTestCase {
    func testSettingsLogsPresentationReflectsExportState() {
        let ready = SettingsLogsPresentation(isExportInProgress: false, canExportLogs: true)
        let exporting = SettingsLogsPresentation(isExportInProgress: true, canExportLogs: false)

        XCTAssertEqual(ready.exportTitle, "Export Logs...")
        XCTAssertEqual(ready.exportSystemImage, "square.and.arrow.up")
        XCTAssertTrue(ready.canExportLogs)
        XCTAssertEqual(exporting.exportTitle, "Exporting Logs...")
        XCTAssertEqual(exporting.exportSystemImage, "hourglass")
        XCTAssertFalse(exporting.canExportLogs)
    }
}
