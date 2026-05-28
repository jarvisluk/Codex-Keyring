import Foundation
@testable import CodexKeyringDomain
@testable import CodexKeyringUI

final class ManualLiveAuthWatcher: LiveAuthWatching, @unchecked Sendable {
    private let queue = DispatchQueue(label: "tests.AccountStore.ManualLiveAuthWatcher")
    private var handler: (@Sendable () -> Void)?

    func start(onChange handler: @escaping @Sendable () -> Void) {
        queue.sync {
            self.handler = handler
        }
    }

    func stop() {
        queue.sync {
            handler = nil
        }
    }

    func trigger() {
        let currentHandler = queue.sync { handler }
        currentHandler?()
    }
}
