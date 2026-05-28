import Foundation
import XCTest
@testable import CodexKeyringDomain
@testable import CodexKeyringInfrastructure

class ChatGPTQuotaClientTestCase: XCTestCase {
    override func tearDown() {
        ChatGPTQuotaMockURLProtocol.reset()
        super.tearDown()
    }

    func makeClient(
        baseURL: URL? = nil,
        ioQueue: DispatchQueue = DispatchQueue(label: "tests.ChatGPTQuotaClient.\(UUID().uuidString)")
    ) throws -> ChatGPTQuotaClient {
        try ChatGPTQuotaClient(
            baseURL: baseURL ?? quotaTestURL("https://chatgpt.test/backend-api"),
            issuer: quotaTestURL("https://auth.test"),
            urlSession: ChatGPTQuotaMockURLProtocol.session,
            ioQueue: ioQueue
        )
    }

    func request(
        snapshotURL: URL,
        liveAuthFileURL: URL? = nil
    ) -> AccountQuotaQueryRequest {
        let id = UUID(uuid: (
            0xAA, 0xAA, 0xAA, 0xAA,
            0xBB, 0xBB,
            0xCC, 0xCC,
            0xDD, 0xDD,
            0xEE, 0xEE, 0xEE, 0xEE, 0xEE, 0xEE
        ))
        let account = CodexAccount(
            id: id,
            alias: "Test",
            email: "person@example.com",
            plan: "plus",
            authMode: "chatgpt",
            accountIdentifier: "account-123",
            snapshotFileName: snapshotURL.lastPathComponent,
            fingerprint: "fingerprint",
            createdAt: Date(timeIntervalSince1970: 1),
            updatedAt: Date(timeIntervalSince1970: 1),
            tokenExpiresAt: nil
        )
        return AccountQuotaQueryRequest(
            account: account,
            snapshotURL: snapshotURL,
            liveAuthFileURL: liveAuthFileURL
        )
    }

    func expiredQuotaAccessToken() throws -> String {
        try makeQuotaJWT(payload: [
            "exp": Date().addingTimeInterval(-3600).timeIntervalSince1970
        ])
    }

    func writeExpiredQuotaAuthJSON(refreshToken: String = "refresh-old") throws -> URL {
        try writeQuotaAuthJSON(
            accessToken: expiredQuotaAccessToken(),
            refreshToken: refreshToken
        )
    }

    func setRefreshTokenResponse(_ object: Any, statusCode: Int = 200) {
        ChatGPTQuotaMockURLProtocol.setHandler { request in
            XCTAssertEqual(request.url?.path, "/oauth/token")
            return try .json(object, statusCode: statusCode)
        }
    }
}
