import Foundation

enum BundledURL {
    static func https(host: String, path: String = "") -> URL {
        var components = URLComponents()
        components.scheme = "https"
        components.host = host
        components.path = path

        guard let url = components.url else {
            assertionFailure("Invalid bundled HTTPS URL: \(host)\(path)")
            return URL(fileURLWithPath: "/")
        }
        return url
    }
}
