import Foundation

func writeAuthParserJSON(_ object: [String: Any]) throws -> URL {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("CodexKeyringTests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let url = directory.appendingPathComponent("auth.json")
    let data = try JSONSerialization.data(withJSONObject: object)
    try data.write(to: url)
    return url
}

func makeAuthParserJWT(payload: [String: Any]) throws -> String {
    let header = ["alg": "none", "typ": "JWT"]
    return [
        try authParserBase64URLEncodedJSON(header),
        try authParserBase64URLEncodedJSON(payload),
        "signature"
    ].joined(separator: ".")
}

private func authParserBase64URLEncodedJSON(_ object: [String: Any]) throws -> String {
    let data = try JSONSerialization.data(withJSONObject: object)
    return data.base64EncodedString()
        .replacingOccurrences(of: "+", with: "-")
        .replacingOccurrences(of: "/", with: "_")
        .replacingOccurrences(of: "=", with: "")
}
