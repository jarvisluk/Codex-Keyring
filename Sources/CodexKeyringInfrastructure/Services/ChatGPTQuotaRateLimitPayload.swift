import Foundation
import CodexKeyringDomain

struct AdditionalRateLimitDTO: Decodable {
    let limitName: String?
    let meteredFeature: String?
    let rateLimit: RateLimitDetails?

    enum CodingKeys: String, CodingKey {
        case limitName = "limit_name"
        case meteredFeature = "metered_feature"
        case rateLimit = "rate_limit"
    }
}
