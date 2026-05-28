import Foundation

extension SyncLiveAuthUseCase {
    func readLiveAuthIfPresent() async throws -> AuthMetadata? {
        try await authReader.readIfPresent(from: installer.liveAuthFileURL)
    }
}
