import Foundation

enum OAuthCallbackRequestParser {
    static func route(from headerData: Data) -> OAuthCallbackHTTPRoute {
        let requestLine = firstLine(of: headerData)
        let components = requestLine.split(separator: " ")
        guard components.count >= 2, components[0] == "GET" else {
            return .methodNotAllowed
        }

        let target = String(components[1])
        guard let url = URL(string: "http://localhost\(target)") else {
            return .badRequest
        }

        switch url.path {
        case "/auth/callback":
            let queryItems = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
            return .callback(queryItems)
        case "/":
            return .root
        default:
            return .notFound
        }
    }

    static func firstLine(of data: Data) -> String {
        if let crlf = data.range(of: Data([0x0D, 0x0A])) {
            return String(data: data.subdata(in: 0..<crlf.lowerBound), encoding: .utf8) ?? ""
        }
        return String(data: data, encoding: .utf8) ?? ""
    }

    static func callbackParameters(from queryItems: [URLQueryItem]) throws -> [String: String] {
        let singleValueNames: Set<String> = ["code", "state", "error", "error_description"]
        var params: [String: String] = [:]
        var seenSingleValueNames = Set<String>()

        for item in queryItems {
            guard singleValueNames.contains(item.name) else { continue }
            guard seenSingleValueNames.insert(item.name).inserted else {
                throw OAuthCallbackServer.ServerError.duplicateParameter(item.name)
            }
            params[item.name] = item.value ?? ""
        }

        return params
    }
}

enum OAuthCallbackHTTPRoute {
    case callback([URLQueryItem])
    case root
    case notFound
    case badRequest
    case methodNotAllowed
}
