import Foundation

extension ChatGPTOAuthTokenExchanger {
    func makeTokenRequest(
        code: String,
        redirectURI: String,
        pkce: PKCECodes
    ) -> URLRequest {
        let tokenURL = issuer.appendingPathComponent("oauth/token")
        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = Data(
            OAuthFormURLEncoder.encode([
                URLQueryItem(name: "grant_type", value: "authorization_code"),
                URLQueryItem(name: "code", value: code),
                URLQueryItem(name: "redirect_uri", value: redirectURI),
                URLQueryItem(name: "client_id", value: clientID),
                URLQueryItem(name: "code_verifier", value: pkce.codeVerifier)
            ]).utf8
        )
        return request
    }
}
