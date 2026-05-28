import Foundation
@testable import CodexKeyringUI

@MainActor
final class RecordingURLAccessScope {
    private(set) var stopCount = 0

    func makeScope() -> URLAccessScope {
        URLAccessScope {
            self.stopCount += 1
        }
    }
}
