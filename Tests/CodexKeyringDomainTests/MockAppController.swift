import Foundation
@testable import CodexKeyringDomain

final class MockAppController: CodexAppControlling, @unchecked Sendable {
    var isRunning = true
    private let outcome: CodexAppRestartOutcome
    private let restartError: Error?
    private(set) var restartCallCount = 0
    private(set) var lastBeforeRelaunchRan = false

    init(outcome: CodexAppRestartOutcome, restartError: Error? = nil) {
        self.outcome = outcome
        self.restartError = restartError
    }

    func restartIfRunning(
        beforeRelaunch: @Sendable () async throws -> Void
    ) async throws -> CodexAppRestartOutcome {
        restartCallCount += 1
        if case .wasNotRunning = outcome {
            return outcome
        }
        try await beforeRelaunch()
        lastBeforeRelaunchRan = true
        if let restartError {
            throw restartError
        }
        return outcome
    }
}
