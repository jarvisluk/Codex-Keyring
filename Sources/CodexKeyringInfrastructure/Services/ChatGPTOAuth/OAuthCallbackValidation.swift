enum OAuthCallbackValidation {
    case success(OAuthCallbackResult)
    case failure(error: OAuthCallbackServer.ServerError, browserMessage: String, logMessage: String)
}

enum OAuthCallbackValidator {
    static func validate(params: [String: String], expectedState: String) -> OAuthCallbackValidation {
        if let errorCode = params["error"], !errorCode.isEmpty {
            let description = params["error_description"]
            let sanitizedError = OAuthErrorSanitizer.providerErrorDescription(
                code: errorCode,
                description: description
            )
            return .failure(
                error: .oauthError(code: errorCode, description: description),
                browserMessage: OAuthErrorSanitizer.browserErrorMessage(
                    code: errorCode,
                    description: description
                ),
                logMessage: "oauth callback failed: \(sanitizedError)"
            )
        }

        let stateValue = params["state"] ?? ""
        guard stateValue == expectedState else {
            return .failure(
                error: .stateMismatch,
                browserMessage: "State mismatch.",
                logMessage: "oauth callback state mismatch"
            )
        }

        guard let code = params["code"], !code.isEmpty else {
            return .failure(
                error: .missingCode,
                browserMessage: "Missing authorization code.",
                logMessage: "oauth callback missing code"
            )
        }

        return .success(OAuthCallbackResult(code: code, state: stateValue))
    }
}
