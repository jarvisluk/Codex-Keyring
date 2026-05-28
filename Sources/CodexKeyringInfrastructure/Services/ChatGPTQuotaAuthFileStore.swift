import Foundation

struct ChatGPTQuotaAuthFileStore: @unchecked Sendable {
    private let ioQueue: DispatchQueue

    init(ioQueue: DispatchQueue) {
        self.ioQueue = ioQueue
    }

    func load(from url: URL) async throws -> StoredChatGPTAuth {
        try await performIO {
            try Self.loadSync(from: url)
        }
    }

    func persist(_ auth: StoredChatGPTAuth, to url: URL) async throws {
        try await performIO {
            try Self.persistSync(auth, to: url)
        }
    }

    private func performIO<T: Sendable>(
        _ work: @escaping @Sendable () throws -> T
    ) async throws -> T {
        try await withCheckedThrowingContinuation { continuation in
            ioQueue.async {
                do {
                    continuation.resume(returning: try work())
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}
