import Foundation

struct CreditsDTO: Decodable {
    let balance: String?
    let hasCredits: Bool
    let unlimited: Bool

    enum CodingKeys: String, CodingKey {
        case balance
        case hasCredits = "has_credits"
        case hasCreditsCamel = "hasCredits"
        case unlimited
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        balance = try container.decodeIfPresent(String.self, forKey: .balance)
        hasCredits = try container.decodeIfPresent(Bool.self, forKey: .hasCredits)
            ?? container.decodeIfPresent(Bool.self, forKey: .hasCreditsCamel)
            ?? false
        unlimited = try container.decodeIfPresent(Bool.self, forKey: .unlimited) ?? false
    }
}
