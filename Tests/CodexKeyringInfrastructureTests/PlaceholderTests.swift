import XCTest
@testable import CodexKeyringInfrastructure

final class PlaceholderTests: XCTestCase {
    func testInfrastructureModuleCompiles() {
        XCTAssertEqual(AppPaths.appName, "CodexKeyring")
    }
}
