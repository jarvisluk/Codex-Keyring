import CryptoKit
import Foundation
import CodexKeyringDomain

/// Codable-backed parser for Codex `auth.json` files.
///
/// Conforms to ``AuthFileReading`` for protocol-driven injection while also
/// exposing a static convenience for code that still uses the legacy API.
public final class AuthFileParser: AuthFileReading, @unchecked Sendable {
    private let log = CodexKeyringLog.makeAppLogger(.authParser)
    private let ioQueue: DispatchQueue

    public init(
        ioQueue: DispatchQueue = DispatchQueue(label: "com.junrong.CodexKeyring.AuthFileParser")
    ) {
        self.ioQueue = ioQueue
    }

    public func read(from url: URL) async throws -> AuthMetadata {
        try await performIO {
            try Self.parseAuthFile(at: url, logger: self.log)
        }
    }

    public static func parseAuthFile(at url: URL) throws -> AuthMetadata {
        try parseAuthFile(at: url, logger: CodexKeyringLog.makeAppLogger(.authParser))
    }

    static func fingerprint(for data: Data) -> String {
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
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
