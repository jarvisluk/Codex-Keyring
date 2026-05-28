import Foundation

enum QuotaClientError: Error {
    case unauthorized
}

struct StoredChatGPTAuth: @unchecked Sendable {
    var sourceObject: [String: Any]
    var accessToken: String
    var refreshToken: String?
    var idToken: String?
    var accountID: String?
    var planType: String?
    var email: String?
}

struct RefreshTokenResponse: Decodable {
    let idToken: String?
    let accessToken: String
    let refreshToken: String?

    enum CodingKeys: String, CodingKey {
        case idToken = "id_token"
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
    }
}
