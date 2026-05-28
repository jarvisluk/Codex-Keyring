import Foundation
@testable import CodexKeyringDomain

final class MockQuotaQuery: AccountQuotaQuerying, @unchecked Sendable {
    private let lock = NSLock()
    private var recordedRequests: [AccountQuotaQueryRequest] = []
    private let handler: (AccountQuotaQueryRequest) async throws -> AccountQuotaQueryResult

    init(handler: @escaping (AccountQuotaQueryRequest) async throws -> AccountQuotaQueryResult) {
        self.handler = handler
    }

    var requests: [AccountQuotaQueryRequest] {
        lock.withLock { recordedRequests }
    }

    func queryQuota(for request: AccountQuotaQueryRequest) async throws -> AccountQuotaQueryResult {
        lock.withLock { recordedRequests.append(request) }
        return try await handler(request)
    }
}
