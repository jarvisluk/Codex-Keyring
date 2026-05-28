import XCTest
@testable import CodexKeyringUI

final class AccountStoreStatusCapabilitiesTests: XCTestCase {
    func testLogExportAvailabilityIsIndependentOfAccountWork() {
        XCTAssertTrue(makeAccountStoreCapabilities(isLoggingAvailable: true).canExportLogs)
        XCTAssertTrue(makeAccountStoreCapabilities(
            isLoggingAvailable: true,
            isRefreshInProgress: true
        ).canExportLogs)
        XCTAssertFalse(makeAccountStoreCapabilities(isLoggingAvailable: false).canExportLogs)
        XCTAssertFalse(makeAccountStoreCapabilities(
            isLoggingAvailable: true,
            isLogExportInProgress: true
        ).canExportLogs)
    }
}
