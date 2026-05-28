import Darwin
import Foundation

extension OAuthCallbackServer {
    func handleCallback(queryItems: [URLQueryItem], clientFD: Int32) {
        let params: [String: String]
        do {
            params = try OAuthCallbackRequestParser.callbackParameters(from: queryItems)
        } catch {
            failCallback(
                clientFD: clientFD,
                error: error,
                browserMessage: error.localizedDescription,
                logMessage: "oauth callback rejected: \(error.localizedDescription)"
            )
            return
        }

        switch OAuthCallbackValidator.validate(params: params, expectedState: expectedState) {
        case .success(let result):
            OAuthCallbackPageRenderer.renderSuccessPage(clientFD: clientFD)
            close(clientFD)
            log.info("oauth callback succeeded")
            finish(with: .success(result))
        case .failure(let error, let browserMessage, let logMessage):
            failCallback(
                clientFD: clientFD,
                error: error,
                browserMessage: browserMessage,
                logMessage: logMessage
            )
        }
    }

    private func failCallback(
        clientFD: Int32,
        error: Error,
        browserMessage: String,
        logMessage: String
    ) {
        OAuthCallbackPageRenderer.renderErrorPage(clientFD: clientFD, message: browserMessage)
        close(clientFD)
        log.error(logMessage)
        finish(with: .failure(error))
    }
}
