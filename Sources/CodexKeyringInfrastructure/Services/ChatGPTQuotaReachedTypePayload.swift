import Foundation

struct ReachedTypeDTO: Decodable {
    let normalizedValue: String?

    enum CodingKeys: String, CodingKey {
        case kind
        case type
    }

    init(from decoder: Decoder) throws {
        if let singleValue = try? decoder.singleValueContainer(),
           !singleValue.decodeNil(),
           let value = try? singleValue.decode(String.self) {
            normalizedValue = value
            return
        }
        let container = try decoder.container(keyedBy: CodingKeys.self)
        normalizedValue = try container.decodeIfPresent(String.self, forKey: .kind)
            ?? container.decodeIfPresent(String.self, forKey: .type)
    }
}
