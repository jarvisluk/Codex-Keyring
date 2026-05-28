@testable import CodexKeyringDomain
@testable import CodexKeyringUI

@MainActor
func waitForQuotaRefreshStarted(
    _ description: String = "automatic quota refresh started",
    repository: BlockingAccountRepository,
    store: AccountStore,
    loadCallCount: Int
) async throws {
    try await waitUntil(description) {
        repository.loadCallCount == loadCallCount && store.isQuotaRefreshInProgress
    }
}

@MainActor
func completeAutomaticQuotaRefresh(
    _ description: String = "automatic quota refresh completed",
    repository: BlockingAccountRepository,
    store: AccountStore,
    loadCallCount: Int,
    returning manifest: AccountManifest? = nil,
    completion: @escaping @MainActor () -> Bool
) async throws {
    try await waitForQuotaRefreshStarted(
        repository: repository,
        store: store,
        loadCallCount: loadCallCount
    )
    repository.resumeNextLoad(returning: manifest)
    try await waitUntil(description) {
        completion() && !store.isOperationInProgress
    }
}

@MainActor
func completeInitialRefreshAndAutomaticQuotaRefresh(
    _ description: String = "automatic quota refresh completed",
    repository: BlockingAccountRepository,
    store: AccountStore,
    completion: @escaping @MainActor () -> Bool
) async throws {
    try await waitForRefreshStarted(repository: repository, store: store)
    repository.resumeNextLoad()
    try await completeAutomaticQuotaRefresh(
        description,
        repository: repository,
        store: store,
        loadCallCount: 2,
        completion: completion
    )
}
