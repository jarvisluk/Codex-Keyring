import Foundation
import CodexKeyringDomain

extension ChatGPTOAuthLoginService {
    public func loginWithChatGPT(
        openAuthURL: @escaping @Sendable (URL) async throws -> Void
    ) async throws {
        let pkce = PKCECodes.generate()
        let state = OAuthRandom.urlSafeToken(byteCount: 32)

        let server: OAuthCallbackServer
        do {
            server = try await OAuthCallbackServer.start(expectedState: state)
        } catch {
            log.error("failed to start callback server: \(error.localizedDescription)")
            throw CodexKeyringError.codexLoginFailed(reason: error.localizedDescription)
        }

        let redirectURI = await server.redirectURI
        let authorizeURL: URL
        do {
            authorizeURL = try buildAuthorizeURL(redirectURI: redirectURI, pkce: pkce, state: state)
        } catch {
            await server.shutdown()
            log.error("failed to build authorization URL: \(error.localizedDescription)")
            throw error
        }

        do {
            log.info("opening ChatGPT auth URL on port resolved from server")
            try await openAuthURL(authorizeURL)
        } catch {
            await server.shutdown()
            log.error("failed to open browser for ChatGPT auth")
            throw CodexKeyringError.codexLoginFailed(reason: Self.browserOpenFailureReason)
        }

        let callback: OAuthCallbackResult
        do {
            callback = try await server.waitForCode()
        } catch {
            await server.shutdown()
            log.error("callback wait failed: \(error.localizedDescription)")
            throw CodexKeyringError.codexLoginFailed(reason: error.localizedDescription)
        }
        await server.shutdown()

        let tokens: ExchangedTokens
        do {
            let tokenExchanger = ChatGPTOAuthTokenExchanger(
                issuer: issuer,
                clientID: clientID,
                urlSession: urlSession
            )
            tokens = try await tokenExchanger.exchangeCodeForTokens(
                code: callback.code,
                redirectURI: redirectURI,
                pkce: pkce
            )
        } catch let error as CodexKeyringError {
            log.error("token exchange failed: \(error.localizedDescription)")
            throw error
        } catch {
            log.error("token exchange failed: \(error.localizedDescription)")
            throw CodexKeyringError.codexLoginFailed(reason: "Token exchange failed: \(error.localizedDescription)")
        }

        do {
            try await persistAuth(tokens: tokens)
        } catch let error as CodexKeyringError {
            throw error
        } catch {
            throw CodexKeyringError.codexLoginFailed(reason: "Could not write auth.json: \(error.localizedDescription)")
        }
    }
}
