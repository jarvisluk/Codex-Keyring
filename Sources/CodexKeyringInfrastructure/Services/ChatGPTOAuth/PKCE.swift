import CryptoKit
import Foundation

/// Mirrors `codex-rs/login/src/pkce.rs`: generates a 64-byte URL-safe base64
/// verifier and a `S256` challenge that is the URL-safe base64 of the
/// verifier's SHA-256 digest (no padding for either value).
struct PKCECodes: Sendable {
    let codeVerifier: String
    let codeChallenge: String

    static func generate() -> PKCECodes {
        var bytes = [UInt8](repeating: 0, count: 64)
        let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        if status != errSecSuccess {
            for index in 0..<bytes.count {
                bytes[index] = UInt8.random(in: 0...UInt8.max)
            }
        }
        let verifier = Data(bytes).base64URLEncodedString()
        let digest = SHA256.hash(data: Data(verifier.utf8))
        let challenge = Data(digest).base64URLEncodedString()
        return PKCECodes(codeVerifier: verifier, codeChallenge: challenge)
    }
}

extension Data {
    /// Base64 with URL-safe alphabet (`-_`) and no padding, matching what
    /// OpenAI's auth server expects for PKCE.
    func base64URLEncodedString() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

enum OAuthRandom {
    static func urlSafeToken(byteCount: Int = 32) -> String {
        var bytes = [UInt8](repeating: 0, count: byteCount)
        let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        if status != errSecSuccess {
            for index in 0..<bytes.count {
                bytes[index] = UInt8.random(in: 0...UInt8.max)
            }
        }
        return Data(bytes).base64URLEncodedString()
    }
}
