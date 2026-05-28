import Foundation
import CodexKeyringDomain

public struct ChatGPTQuotaClient: AccountQuotaQuerying, @unchecked Sendable {
    public static let defaultBaseURL = BundledURL.https(
        host: "chatgpt.com",
        path: "/backend-api"
    )

    let httpClient: ChatGPTQuotaHTTPClient
    let authReader: AuthFileReading
    let authStore: ChatGPTQuotaAuthFileStore

    public init(
        baseURL: URL = Self.defaultBaseURL,
        issuer: URL = ChatGPTOAuthLoginService.openAIIssuer,
        clientID: String = ChatGPTOAuthLoginService.clientID,
        urlSession: URLSession = .shared,
        authReader: AuthFileReading = AuthFileParser(),
        ioQueue: DispatchQueue = DispatchQueue(label: "com.junrong.CodexKeyring.QuotaClient")
    ) {
        self.httpClient = ChatGPTQuotaHTTPClient(
            baseURL: baseURL,
            issuer: issuer,
            clientID: clientID,
            urlSession: urlSession
        )
        self.authReader = authReader
        self.authStore = ChatGPTQuotaAuthFileStore(ioQueue: ioQueue)
    }

    public func queryQuota(for request: AccountQuotaQueryRequest) async throws -> AccountQuotaQueryResult {
        var auth = try await authStore.load(from: request.snapshotURL)
        var updatedMetadata: AuthMetadata?

        if shouldRefreshAccessToken(auth.accessToken) {
            (auth, updatedMetadata) = try await refreshAuthAndMetadata(auth, request: request)
        }

        do {
            return try await queryUsage(auth: auth, request: request, updatedMetadata: updatedMetadata)
        } catch QuotaClientError.unauthorized where auth.refreshToken?.isEmpty == false {
            (auth, updatedMetadata) = try await refreshAuthAndMetadata(auth, request: request)
            return try await queryUsage(auth: auth, request: request, updatedMetadata: updatedMetadata)
        } catch QuotaClientError.unauthorized {
            throw CodexKeyringError.quotaRequiresRelogin(reason: "The saved access token was rejected and no refresh token is available.")
        }
    }
}
