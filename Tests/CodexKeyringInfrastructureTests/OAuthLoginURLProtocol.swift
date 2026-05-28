import Foundation

struct OAuthLoginMockResponse {
    var statusCode: Int
    var headers: [String: String]
    var data: Data

    static func json(_ object: Any, statusCode: Int = 200) throws -> OAuthLoginMockResponse {
        OAuthLoginMockResponse(
            statusCode: statusCode,
            headers: ["Content-Type": "application/json"],
            data: try JSONSerialization.data(withJSONObject: object)
        )
    }
}

final class OAuthLoginURLProtocol: URLProtocol {
    private static let lock = NSLock()
    nonisolated(unsafe) private static var handler: ((URLRequest) throws -> OAuthLoginMockResponse)?
    nonisolated(unsafe) private static var capturedRequests: [URLRequest] = []

    static var requests: [URLRequest] {
        lock.withLock { capturedRequests }
    }

    static var session: URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [OAuthLoginURLProtocol.self]
        return URLSession(configuration: configuration)
    }

    static func setHandler(_ handler: @escaping (URLRequest) throws -> OAuthLoginMockResponse) {
        lock.withLock {
            self.handler = handler
        }
    }

    static func reset() {
        lock.withLock {
            handler = nil
            capturedRequests = []
        }
    }

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        do {
            let currentHandler = Self.lock.withLock {
                Self.capturedRequests.append(request)
                return Self.handler
            }
            guard let currentHandler else {
                throw URLError(.badServerResponse)
            }
            let response = try currentHandler(request)
            guard let url = request.url,
                  let http = HTTPURLResponse(
                      url: url,
                      statusCode: response.statusCode,
                      httpVersion: "HTTP/1.1",
                      headerFields: response.headers
                  )
            else {
                throw URLError(.badServerResponse)
            }
            client?.urlProtocol(self, didReceive: http, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: response.data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
