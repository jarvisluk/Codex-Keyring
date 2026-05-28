import Foundation
import XCTest
@testable import CodexKeyringInfrastructure

func authObject(at url: URL) throws -> [String: Any] {
    let data = try Data(contentsOf: url)
    return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
}

func requestBodyString(from request: URLRequest) -> String {
    if let body = request.httpBody {
        return String(data: body, encoding: .utf8) ?? ""
    }
    guard let stream = request.httpBodyStream else { return "" }
    stream.open()
    defer { stream.close() }

    var data = Data()
    var buffer = [UInt8](repeating: 0, count: 1024)
    while stream.hasBytesAvailable {
        let count = stream.read(&buffer, maxLength: buffer.count)
        if count <= 0 { break }
        data.append(buffer, count: count)
    }
    return String(data: data, encoding: .utf8) ?? ""
}

func completeLoginCallback(for authorizeURL: URL, code: String = "callback-code") async throws {
    let components = try XCTUnwrap(URLComponents(url: authorizeURL, resolvingAgainstBaseURL: false))
    let redirectURI = try XCTUnwrap(components.queryItems?.first { $0.name == "redirect_uri" }?.value)
    let state = try XCTUnwrap(components.queryItems?.first { $0.name == "state" }?.value)
    var callback = try XCTUnwrap(URLComponents(string: redirectURI))
    callback.queryItems = [
        URLQueryItem(name: "code", value: code),
        URLQueryItem(name: "state", value: state)
    ]
    _ = try await URLSession.shared.data(from: try XCTUnwrap(callback.url))
}

func completeOAuthLogin(_ service: ChatGPTOAuthLoginService) async throws {
    try await service.loginWithChatGPT { authorizeURL in
        try await completeLoginCallback(for: authorizeURL)
    }
}

func filePermissions(at url: URL) throws -> Int {
    let value = try XCTUnwrap(
        FileManager.default.attributesOfItem(atPath: url.path)[.posixPermissions] as? NSNumber
    )
    return value.intValue & 0o777
}

func oauthTestURL(
    _ string: String,
    file: StaticString = #filePath,
    line: UInt = #line
) throws -> URL {
    try XCTUnwrap(URL(string: string), file: file, line: line)
}

func oauthTestJWT(payload: [String: Any]) throws -> String {
    let header = ["alg": "none", "typ": "JWT"]
    return [
        try oauthTestBase64URLJSON(header),
        try oauthTestBase64URLJSON(payload),
        "signature"
    ].joined(separator: ".")
}

private func oauthTestBase64URLJSON(_ object: [String: Any]) throws -> String {
    let data = try JSONSerialization.data(withJSONObject: object)
    return data.base64EncodedString()
        .replacingOccurrences(of: "+", with: "-")
        .replacingOccurrences(of: "/", with: "_")
        .replacingOccurrences(of: "=", with: "")
}
