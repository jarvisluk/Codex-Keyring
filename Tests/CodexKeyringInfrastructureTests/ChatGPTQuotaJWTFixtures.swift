import Foundation
import XCTest

func quotaTestURL(
    _ string: String,
    file: StaticString = #filePath,
    line: UInt = #line
) throws -> URL {
    try XCTUnwrap(URL(string: string), file: file, line: line)
}

func makeQuotaJWT(payload: [String: Any]) throws -> String {
    let header = ["alg": "none", "typ": "JWT"]
    return [
        try quotaBase64URLEncodedJSON(header),
        try quotaBase64URLEncodedJSON(payload),
        "signature"
    ].joined(separator: ".")
}

func quotaBase64URLEncodedJSON(_ object: [String: Any]) throws -> String {
    let data = try JSONSerialization.data(withJSONObject: object)
    return data.base64EncodedString()
        .replacingOccurrences(of: "+", with: "-")
        .replacingOccurrences(of: "/", with: "_")
        .replacingOccurrences(of: "=", with: "")
}
