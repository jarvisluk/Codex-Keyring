import XCTest
@testable import CodexKeyringUI

final class SettingsPresentationStoreTests: XCTestCase {
    @MainActor
    func testSettingsPresentationStoreTogglesModalState() {
        let store = SettingsPresentationStore()

        XCTAssertFalse(store.isPresented)

        store.present()
        XCTAssertTrue(store.isPresented)

        store.dismiss()
        XCTAssertFalse(store.isPresented)
    }
}
