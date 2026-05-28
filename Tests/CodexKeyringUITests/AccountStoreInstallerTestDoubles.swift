import Foundation
@testable import CodexKeyringDomain

struct NoopInstaller: CodexAuthInstalling {
    let liveAuthFileURL = URL(fileURLWithPath: "/tmp/auth.json")

    func install(snapshot: URL) async throws {}
    func backupCurrent() async throws -> URL? { nil }
    func stageLiveAuthIfPresent(prefix: String) async throws -> URL? { nil }
    func stageRequiredLiveAuth(prefix: String) async throws -> URL { liveAuthFileURL }
    func restoreLiveAuth(from stagedURL: URL?) async throws {}
    func removeStagedAuth(_ url: URL?) async throws {}
}

struct StagedLoginInstaller: CodexAuthInstalling {
    let liveAuthFileURL: URL
    let preLoginURL: URL?
    let newLoginURL: URL
    let cleanupError: Error?

    func install(snapshot: URL) async throws {}
    func backupCurrent() async throws -> URL? { nil }

    func stageLiveAuthIfPresent(prefix: String) async throws -> URL? {
        preLoginURL
    }

    func stageRequiredLiveAuth(prefix: String) async throws -> URL {
        newLoginURL
    }

    func restoreLiveAuth(from stagedURL: URL?) async throws {}

    func removeStagedAuth(_ url: URL?) async throws {
        if let cleanupError {
            throw cleanupError
        }
    }
}
