import Foundation

struct ChatGPTQuotaMockResponse {
    var statusCode: Int
    var headers: [String: String]
    var data: Data

    static func json(_ object: Any, statusCode: Int = 200) throws -> ChatGPTQuotaMockResponse {
        ChatGPTQuotaMockResponse(
            statusCode: statusCode,
            headers: ["Content-Type": "application/json"],
            data: try JSONSerialization.data(withJSONObject: object)
        )
    }

    static func status(_ statusCode: Int) -> ChatGPTQuotaMockResponse {
        ChatGPTQuotaMockResponse(statusCode: statusCode, headers: [:], data: Data())
    }
}

final class ChatGPTQuotaMockURLProtocol: URLProtocol {
    private static let lock = NSLock()
    nonisolated(unsafe) private static var handler: ((URLRequest) throws -> ChatGPTQuotaMockResponse)?
    nonisolated(unsafe) private static var recordedRequests: [URLRequest] = []

    static var session: URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [ChatGPTQuotaMockURLProtocol.self]
        return URLSession(configuration: configuration)
    }

    static var requests: [URLRequest] {
        lock.withLock { recordedRequests }
    }

    static func setHandler(_ handler: @escaping (URLRequest) throws -> ChatGPTQuotaMockResponse) {
        lock.withLock {
            self.handler = handler
            recordedRequests = []
        }
    }

    static func reset() {
        lock.withLock {
            handler = nil
            recordedRequests = []
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
            let currentHandler = Self.lock.withLock { Self.handler }
            guard let currentHandler else {
                throw URLError(.badServerResponse)
            }
            Self.lock.withLock { Self.recordedRequests.append(request) }
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
