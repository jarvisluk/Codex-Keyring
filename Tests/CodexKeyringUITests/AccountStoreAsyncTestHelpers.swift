import Foundation
import XCTest
@testable import CodexKeyringDomain
@testable import CodexKeyringUI

@MainActor
func waitUntil(
    _ description: String,
    timeout: TimeInterval = 1,
    predicate: @escaping @MainActor () -> Bool
) async throws {
    let deadline = Date().addingTimeInterval(timeout)
    while !predicate() {
        if Date() >= deadline {
            XCTFail("Timed out waiting for \(description)")
            return
        }
        try await Task.sleep(nanoseconds: 10_000_000)
    }
}

@MainActor
func completeInitialRefresh(
    repository: BlockingAccountRepository,
    store: AccountStore
) async throws {
    try await waitForRefreshStarted(repository: repository, store: store)
    try await finishPendingRefresh("initial refresh completed", repository: repository, store: store)
}

@MainActor
func retryAndCompleteRefresh(
    repository: BlockingAccountRepository,
    store: AccountStore
) async throws {
    store.refresh()
    try await waitForRefreshStarted(
        "retry refresh started",
        repository: repository,
        store: store,
        loadCallCount: 2
    )
    try await finishPendingRefresh("retry refresh completed", repository: repository, store: store)
}

@MainActor
func failPendingRefresh(
    repository: BlockingAccountRepository,
    store: AccountStore,
    reason: String
) async throws {
    try await waitForRefreshStarted(repository: repository, store: store)
    repository.resumeNextLoad(throwing: CodexKeyringError.fileSystemFailure(reason: reason))
    try await waitUntil("initial refresh failed") {
        store.lastError == "Local storage operation failed: \(reason)"
            && !store.isOperationInProgress
    }
}

@MainActor
func waitForRefreshStarted(
    _ description: String = "initial refresh started",
    repository: BlockingAccountRepository,
    store: AccountStore,
    loadCallCount: Int = 1
) async throws {
    try await waitUntil(description) {
        repository.loadCallCount == loadCallCount && store.isRefreshInProgress
    }
}

@MainActor
func finishPendingRefresh(
    _ description: String,
    repository: BlockingAccountRepository,
    store: AccountStore
) async throws {
    repository.resumeNextLoad()
    try await waitUntil(description) {
        !store.isOperationInProgress
    }
}
