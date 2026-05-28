import Foundation
@testable import CodexKeyringDomain
@testable import CodexKeyringUI

struct NoopAppController: CodexAppControlling {
    var isRunning: Bool { false }

    func restartIfRunning(
        beforeRelaunch: @Sendable () async throws -> Void
    ) async throws -> CodexAppRestartOutcome {
        .wasNotRunning
    }
}

struct RelaunchingAppController: CodexAppControlling {
    var isRunning: Bool { true }

    func restartIfRunning(
        beforeRelaunch: @Sendable () async throws -> Void
    ) async throws -> CodexAppRestartOutcome {
        try await beforeRelaunch()
        return .relaunched
    }
}

struct FailingRestartAppController: CodexAppControlling {
    let reason: String
    var isRunning: Bool { true }

    func restartIfRunning(
        beforeRelaunch: @Sendable () async throws -> Void
    ) async throws -> CodexAppRestartOutcome {
        try await beforeRelaunch()
        throw CodexKeyringError.codexAppRelaunchFailed(reason: reason)
    }
}
