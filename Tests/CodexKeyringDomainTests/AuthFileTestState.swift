import Foundation
@testable import CodexKeyringDomain

final class AuthFileRegistry: @unchecked Sendable {
    private let lock = NSLock()
    private var files: [URL: AuthMetadata]

    init(_ files: [URL: AuthMetadata]) {
        self.files = files
    }

    func metadata(for url: URL) -> AuthMetadata? {
        lock.withLock { files[url] }
    }

    func set(_ metadata: AuthMetadata, for url: URL) {
        lock.withLock { files[url] = metadata }
    }

    func remove(_ url: URL) {
        _ = lock.withLock { files.removeValue(forKey: url) }
    }
}

final class URLRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var recordedURL: URL?

    var url: URL? {
        get { lock.withLock { recordedURL } }
        set { lock.withLock { recordedURL = newValue } }
    }
}
