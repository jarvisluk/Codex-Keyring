import Foundation
@testable import CodexKeyringDomain
@testable import CodexKeyringUI

struct NoopLoginService: CodexLoginServicing {
    func loginWithChatGPT(
        openAuthURL: @escaping @Sendable (URL) async throws -> Void
    ) async throws {}
}

final class BlockingLoginService: CodexLoginServicing, @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<Void, Error>?
    private var _startedCount = 0

    var startedCount: Int {
        lock.withLock { _startedCount }
    }

    func loginWithChatGPT(
        openAuthURL: @escaping @Sendable (URL) async throws -> Void
    ) async throws {
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                lock.withLock {
                    _startedCount += 1
                    self.continuation = continuation
                }
            }
        } onCancel: {
            fail(with: CancellationError())
        }
    }

    func fail(with error: Error) {
        let continuation = lock.withLock {
            let current = self.continuation
            self.continuation = nil
            return current
        }
        continuation?.resume(throwing: error)
    }
}
