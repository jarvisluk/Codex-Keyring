import Foundation

struct RateLimitResetCreditsSummaryDTO: Decodable {
    let availableCount: Int

    enum CodingKeys: String, CodingKey {
        case availableCount = "available_count"
        case availableCountCamel = "availableCount"
    }

    init(availableCount: Int) {
        self.availableCount = max(0, availableCount)
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        availableCount = max(
            0,
            try container.decodeLossyInt(forKey: .availableCount)
                ?? container.decodeLossyInt(forKey: .availableCountCamel)
                ?? 0
        )
    }
}

struct RateLimitResetCreditsPayload: Decodable {
    let availableCount: Int
    let credits: [RateLimitResetCreditDTO]

    enum CodingKeys: String, CodingKey {
        case availableCount = "available_count"
        case availableCountCamel = "availableCount"
        case credits
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        availableCount = max(
            0,
            try container.decodeLossyInt(forKey: .availableCount)
                ?? container.decodeLossyInt(forKey: .availableCountCamel)
                ?? 0
        )
        credits = try container.decodeIfPresent([RateLimitResetCreditDTO].self, forKey: .credits) ?? []
    }
}

struct RateLimitResetCreditDTO: Decodable {
    let id: String?
    let title: String?
    let description: String?
    let status: String?
    let expiresAt: Date?
    let expiresInSeconds: TimeInterval?
    let profileUserID: String?
    let profileImageURL: String?

    enum CodingKeys: String, CodingKey {
        case id
        case creditID = "credit_id"
        case creditIDCamel = "creditId"
        case title
        case description
        case status
        case expiresAt = "expires_at"
        case expiresAtCamel = "expiresAt"
        case expiresAtMilliseconds = "expires_at_ms"
        case expiresAtMillisecondsCamel = "expiresAtMs"
        case expires = "expires"
        case expirationAt = "expiration_at"
        case expirationAtCamel = "expirationAt"
        case expirationTime = "expiration_time"
        case expirationTimeCamel = "expirationTime"
        case expiresIn = "expires_in"
        case expiresInCamel = "expiresIn"
        case expiresInSeconds = "expires_in_seconds"
        case expiresInSecondsCamel = "expiresInSeconds"
        case profileUserID = "profile_user_id"
        case profileUserIDCamel = "profileUserId"
        case profileImageURL = "profile_image_url"
        case profileImageURLCamel = "profileImageUrl"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeTrimmedString(forKey: .id)
            ?? container.decodeTrimmedString(forKey: .creditID)
            ?? container.decodeTrimmedString(forKey: .creditIDCamel)
        title = try container.decodeTrimmedString(forKey: .title)
        description = try container.decodeTrimmedString(forKey: .description)
        status = try container.decodeTrimmedString(forKey: .status)
        profileUserID = try container.decodeTrimmedString(forKey: .profileUserID)
            ?? container.decodeTrimmedString(forKey: .profileUserIDCamel)
        profileImageURL = try container.decodeTrimmedString(forKey: .profileImageURL)
            ?? container.decodeTrimmedString(forKey: .profileImageURLCamel)
        expiresAt = try Self.decodeExpirationDate(from: container)
        expiresInSeconds = try container.decodeLossyTimeInterval(forKey: .expiresIn)
            ?? container.decodeLossyTimeInterval(forKey: .expiresInCamel)
            ?? container.decodeLossyTimeInterval(forKey: .expiresInSeconds)
            ?? container.decodeLossyTimeInterval(forKey: .expiresInSecondsCamel)
    }

    private static func decodeExpirationDate(
        from container: KeyedDecodingContainer<CodingKeys>
    ) throws -> Date? {
        for key in [
            CodingKeys.expiresAt,
            .expiresAtCamel,
            .expiresAtMilliseconds,
            .expiresAtMillisecondsCamel,
            .expires,
            .expirationAt,
            .expirationAtCamel,
            .expirationTime,
            .expirationTimeCamel
        ] {
            if let date = try container.decodeLossyDate(forKey: key) {
                return date
            }
        }
        return nil
    }
}

private extension KeyedDecodingContainer {
    func decodeTrimmedString(forKey key: Key) throws -> String? {
        guard let value = try? decodeIfPresent(String.self, forKey: key)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
            !value.isEmpty
        else {
            return nil
        }
        return value
    }

    func decodeLossyInt(forKey key: Key) throws -> Int? {
        if let value = try? decodeIfPresent(Int.self, forKey: key) {
            return value
        }
        if let value = try? decodeIfPresent(Double.self, forKey: key) {
            return Int(value)
        }
        guard let value = try decodeTrimmedString(forKey: key) else {
            return nil
        }
        if let intValue = Int(value) {
            return intValue
        }
        if let doubleValue = Double(value) {
            return Int(doubleValue)
        }
        return nil
    }

    func decodeLossyTimeInterval(forKey key: Key) throws -> TimeInterval? {
        if let value = try? decodeIfPresent(Double.self, forKey: key) {
            return value
        }
        if let value = try? decodeIfPresent(Int.self, forKey: key) {
            return TimeInterval(value)
        }
        guard let value = try decodeTrimmedString(forKey: key) else {
            return nil
        }
        return TimeInterval(value)
    }

    func decodeLossyDate(forKey key: Key) throws -> Date? {
        if let value = try? decodeIfPresent(Double.self, forKey: key) {
            return Date(timeIntervalSince1970: normalizedUnixTimestamp(value))
        }
        if let value = try? decodeIfPresent(Int.self, forKey: key) {
            return Date(timeIntervalSince1970: normalizedUnixTimestamp(TimeInterval(value)))
        }
        guard let value = try decodeTrimmedString(forKey: key) else {
            return nil
        }
        if let numeric = TimeInterval(value) {
            return Date(timeIntervalSince1970: normalizedUnixTimestamp(numeric))
        }
        return ISO8601DateParser.parse(value)
    }

    private func normalizedUnixTimestamp(_ value: TimeInterval) -> TimeInterval {
        value > 10_000_000_000 ? value / 1_000 : value
    }
}

private enum ISO8601DateParser {
    static func parse(_ value: String) -> Date? {
        let fractionalFormatter = ISO8601DateFormatter()
        fractionalFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractionalFormatter.date(from: value) {
            return date
        }

        let standardFormatter = ISO8601DateFormatter()
        standardFormatter.formatOptions = [.withInternetDateTime]
        return standardFormatter.date(from: value)
    }
}
