import XCTest
@testable import CodexKeyringUI

final class SettingsPresentationStoreTests: XCTestCase {
    @MainActor
    func testSettingsPresentationStoreTracksNativeWindowVisibility() {
        let store = SettingsPresentationStore()

        XCTAssertFalse(store.isPresented)

        store.present()
        XCTAssertTrue(store.isPresented)

        store.dismiss()
        XCTAssertFalse(store.isPresented)
    }
}
