import Foundation
import CodexKeyringDomain

struct UsagePayload: Decodable {
    let planType: String?
    let email: String?
    let rateLimit: RateLimitDetails?
    let credits: CreditsDTO?
    let rateLimitReachedType: ReachedTypeDTO?
    let additionalRateLimits: [AdditionalRateLimitDTO]?
    let rateLimitResetCredits: RateLimitResetCreditsSummaryDTO?

    enum CodingKeys: String, CodingKey {
        case planType = "plan_type"
        case email
        case rateLimit = "rate_limit"
        case rateLimits = "rate_limits"
        case credits
        case rateLimitReachedType = "rate_limit_reached_type"
        case additionalRateLimits = "additional_rate_limits"
        case rateLimitResetCredits = "rate_limit_reset_credits"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        planType = try container.decodeIfPresent(String.self, forKey: .planType)
        email = try container.decodeIfPresent(String.self, forKey: .email)
        rateLimit = try container.decodeIfPresent(RateLimitDetails.self, forKey: .rateLimit)
            ?? container.decodeIfPresent(RateLimitDetails.self, forKey: .rateLimits)
        credits = try container.decodeIfPresent(CreditsDTO.self, forKey: .credits)
        rateLimitReachedType = try container.decodeIfPresent(ReachedTypeDTO.self, forKey: .rateLimitReachedType)
        additionalRateLimits = try container.decodeIfPresent([AdditionalRateLimitDTO].self, forKey: .additionalRateLimits)
        rateLimitResetCredits = try container.decodeIfPresent(
            RateLimitResetCreditsSummaryDTO.self,
            forKey: .rateLimitResetCredits
        )
    }
}
