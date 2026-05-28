import Foundation
@testable import CodexKeyringDomain

final class BlockingAccountRepository: AccountRepository, @unchecked Sendable {
    private let queue = DispatchQueue(label: "tests.AccountStore.BlockingAccountRepository")
    private var manifest: AccountManifest
    private let snapshotExistsValue: Bool
    private var pendingLoads: [CheckedContinuation<AccountManifest, Error>] = []
    private var _loadCallCount = 0

    init(manifest: AccountManifest, snapshotExists: Bool = false) {
        self.manifest = manifest
        self.snapshotExistsValue = snapshotExists
    }

    var loadCallCount: Int {
        queue.sync { _loadCallCount }
    }

    func load() async throws -> AccountManifest {
        try await withCheckedThrowingContinuation { continuation in
            queue.sync {
                _loadCallCount += 1
                pendingLoads.append(continuation)
            }
        }
    }

    func save(_ manifest: AccountManifest) async throws {
        queue.sync {
            self.manifest = manifest
        }
    }

    func writeSnapshot(from source: URL, for accountID: UUID) async throws -> String {
        "\(accountID.uuidString).auth.json"
    }

    func deleteSnapshot(named fileName: String) async throws {}

    func snapshotURL(named fileName: String) -> URL {
        URL(fileURLWithPath: "/tmp/\(fileName)")
    }

    func snapshotExists(named fileName: String) -> Bool {
        snapshotExistsValue
    }

    func resumeNextLoad(returning overrideManifest: AccountManifest? = nil) {
        let (continuation, value) = queue.sync {
            precondition(!pendingLoads.isEmpty, "No pending load to resume")
            return (pendingLoads.removeFirst(), overrideManifest ?? manifest)
        }
        continuation.resume(returning: value)
    }

    func resumeNextLoad(throwing error: Error) {
        let continuation = queue.sync {
            precondition(!pendingLoads.isEmpty, "No pending load to resume")
            return pendingLoads.removeFirst()
        }
        continuation.resume(throwing: error)
    }
}
