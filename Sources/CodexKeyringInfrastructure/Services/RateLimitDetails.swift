import Foundation

struct RateLimitDetails: Decodable {
    let limitID: String?
    let limitName: String?
    let planType: String?
    let primaryWindow: RateLimitWindowDTO?
    let secondaryWindow: RateLimitWindowDTO?
    let credits: CreditsDTO?
    let rateLimitReachedType: ReachedTypeDTO?

    enum CodingKeys: String, CodingKey {
        case limitID = "limit_id"
        case limitName = "limit_name"
        case planType = "plan_type"
        case primaryWindow = "primary_window"
        case secondaryWindow = "secondary_window"
        case primary
        case secondary
        case credits
        case rateLimitReachedType = "rate_limit_reached_type"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        limitID = try container.decodeIfPresent(String.self, forKey: .limitID)
        limitName = try container.decodeIfPresent(String.self, forKey: .limitName)
        planType = try container.decodeIfPresent(String.self, forKey: .planType)
        primaryWindow = try container.decodeIfPresent(RateLimitWindowDTO.self, forKey: .primaryWindow)
            ?? container.decodeIfPresent(RateLimitWindowDTO.self, forKey: .primary)
        secondaryWindow = try container.decodeIfPresent(RateLimitWindowDTO.self, forKey: .secondaryWindow)
            ?? container.decodeIfPresent(RateLimitWindowDTO.self, forKey: .secondary)
        credits = try container.decodeIfPresent(CreditsDTO.self, forKey: .credits)
        rateLimitReachedType = try container.decodeIfPresent(ReachedTypeDTO.self, forKey: .rateLimitReachedType)
    }
}
