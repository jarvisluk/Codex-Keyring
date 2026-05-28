import Foundation
import XCTest

func writeQuotaAuthJSON(
    accessToken: String,
    refreshToken: String = "refresh-token",
    idToken: String? = nil,
    accountID: String? = "account-123"
) throws -> URL {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("CodexKeyringQuotaTests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let url = directory.appendingPathComponent("auth.json")
    let idToken = try idToken ?? makeQuotaJWT(payload: [
        "email": "person@example.com",
        "https://api.openai.com/auth": [
            "chatgpt_plan_type": "plus",
            "chatgpt_account_id": "account-123"
        ]
    ])
    var tokens: [String: Any] = [
        "access_token": accessToken,
        "refresh_token": refreshToken,
        "id_token": idToken
    ]
    if let accountID {
        tokens["account_id"] = accountID
    }
    let object: [String: Any] = [
        "auth_mode": "chatgpt",
        "tokens": tokens
    ]
    try JSONSerialization.data(withJSONObject: object).write(to: url)
    return url
}

func writeRefreshOnlyQuotaAuthJSON(refreshToken: String) throws -> URL {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("CodexKeyringQuotaTests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let url = directory.appendingPathComponent("auth.json")
    let object: [String: Any] = [
        "auth_mode": "chatgpt",
        "tokens": [
            "refresh_token": refreshToken
        ]
    ]
    try JSONSerialization.data(withJSONObject: object).write(to: url)
    return url
}

func overwriteQuotaAuthJSON(
    at url: URL,
    accessToken: String,
    refreshToken: String = "refresh-token",
    idToken: String? = nil
) throws {
    let idToken = try idToken ?? makeQuotaJWT(payload: [
        "email": "person@example.com",
        "https://api.openai.com/auth": [
            "chatgpt_plan_type": "plus"
        ]
    ])
    let object: [String: Any] = [
        "auth_mode": "chatgpt",
        "tokens": [
            "access_token": accessToken,
            "refresh_token": refreshToken,
            "id_token": idToken
        ]
    ]
    try JSONSerialization.data(withJSONObject: object).write(to: url)
}

func quotaTokenValue(_ key: String, in url: URL) throws -> String? {
    let data = try Data(contentsOf: url)
    let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
    let tokens = object?["tokens"] as? [String: Any]
    return tokens?[key] as? String
}

func quotaFilePermissions(at url: URL) throws -> Int {
    let value = try XCTUnwrap(
        FileManager.default.attributesOfItem(atPath: url.path)[.posixPermissions] as? NSNumber
    )
    return value.intValue & 0o777
}
