import XCTest
@testable import CodexKeyringDomain

final class PlaceholderTests: XCTestCase {
    func testDomainModuleCompiles() {
        XCTAssertEqual(AppSettings().restartCodexAppAfterSwitch, false)
    }
}
