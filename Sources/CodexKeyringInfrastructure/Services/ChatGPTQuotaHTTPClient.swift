import Foundation
import CodexKeyringDomain

struct ChatGPTQuotaHTTPClient: @unchecked Sendable {
    let baseURL: URL
    let issuer: URL
    let clientID: String
    let urlSession: URLSession

    var usageURL: URL {
        baseURL
            .appendingPathComponent("wham")
            .appendingPathComponent("usage")
    }

    var rateLimitResetCreditsURL: URL {
        baseURL
            .appendingPathComponent("wham")
            .appendingPathComponent("rate-limit-reset-credits")
    }
}
