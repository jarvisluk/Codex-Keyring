import Foundation
@testable import CodexKeyringDomain

final class MockAgentPreferencesPort: CodexAgentPreferencesPorting, @unchecked Sendable {
    private let lock = NSLock()
    private var captureValues: [AccountAgentPreferences]
    private var projectArrangement: CodexProjectArrangement
    private let captureError: Error?
    private let projectArrangementCaptureError: Error?
    private let applyError: Error?
    private let projectArrangementRestoreError: Error?
    private var captureIndex = 0
    private(set) var captureCallCount = 0
    private(set) var applyCallCount = 0
    private(set) var projectArrangementCaptureCallCount = 0
    private(set) var projectArrangementRestoreCallCount = 0
    private(set) var applied: [AccountAgentPreferences] = []
    private(set) var restoredProjectArrangements: [CodexProjectArrangement] = []

    init(
        captureValues: [AccountAgentPreferences] = [],
        projectArrangement: CodexProjectArrangement = CodexProjectArrangement(),
        captureError: Error? = nil,
        projectArrangementCaptureError: Error? = nil,
        applyError: Error? = nil,
        projectArrangementRestoreError: Error? = nil
    ) {
        self.captureValues = captureValues
        self.projectArrangement = projectArrangement
        self.captureError = captureError
        self.projectArrangementCaptureError = projectArrangementCaptureError
        self.applyError = applyError
        self.projectArrangementRestoreError = projectArrangementRestoreError
    }

    func captureCurrent() async throws -> AccountAgentPreferences {
        if let captureError {
            lock.withLock { captureCallCount += 1 }
            throw captureError
        }
        return lock.withLock {
            captureCallCount += 1
            guard captureIndex < captureValues.count else {
                return AccountAgentPreferences()
            }
            defer { captureIndex += 1 }
            return captureValues[captureIndex]
        }
    }

    func apply(_ preferences: AccountAgentPreferences) async throws {
        lock.withLock { applyCallCount += 1 }
        if let applyError {
            throw applyError
        }
        lock.withLock { applied.append(preferences) }
    }

    func captureProjectArrangement() async throws -> CodexProjectArrangement {
        if let projectArrangementCaptureError {
            lock.withLock { projectArrangementCaptureCallCount += 1 }
            throw projectArrangementCaptureError
        }
        return lock.withLock {
            projectArrangementCaptureCallCount += 1
            return projectArrangement
        }
    }

    func restoreProjectArrangement(_ arrangement: CodexProjectArrangement) async throws {
        lock.withLock { projectArrangementRestoreCallCount += 1 }
        if let projectArrangementRestoreError {
            throw projectArrangementRestoreError
        }
        lock.withLock { restoredProjectArrangements.append(arrangement) }
    }
}
