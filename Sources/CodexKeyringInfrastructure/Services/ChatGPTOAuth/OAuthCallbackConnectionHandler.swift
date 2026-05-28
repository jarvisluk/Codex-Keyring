import Darwin
import Foundation

enum OAuthCallbackConnectionHandler {
    static func handle(clientFD: Int32, onCallback: OAuthCallbackHandler) {
        applySocketTimeouts(to: clientFD)

        let headerData = OAuthCallbackConnectionReader.readHeader(from: clientFD)
        switch OAuthCallbackRequestParser.route(from: headerData) {
        case .methodNotAllowed:
            writeResponseAndClose(
                clientFD: clientFD,
                status: 405,
                reason: "Method Not Allowed",
                body: "Method Not Allowed"
            )
        case .badRequest:
            writeResponseAndClose(
                clientFD: clientFD,
                status: 400,
                reason: "Bad Request",
                body: "Bad Request"
            )
        case .callback(let queryItems):
            // Ownership of the fd transfers to the actor-bound callback handler,
            // which writes the response and then closes the socket itself.
            onCallback(queryItems, clientFD)
        case .root:
            writeResponseAndClose(
                clientFD: clientFD,
                status: 200,
                reason: "OK",
                body: "Codex Keyring OAuth callback server is running."
            )
        case .notFound:
            writeResponseAndClose(
                clientFD: clientFD,
                status: 404,
                reason: "Not Found",
                body: "Not Found"
            )
        }
    }

    private static func applySocketTimeouts(to clientFD: Int32) {
        var timeout = timeval(tv_sec: 10, tv_usec: 0)
        _ = setsockopt(
            clientFD,
            SOL_SOCKET,
            SO_RCVTIMEO,
            &timeout,
            socklen_t(MemoryLayout<timeval>.size)
        )
        _ = setsockopt(
            clientFD,
            SOL_SOCKET,
            SO_SNDTIMEO,
            &timeout,
            socklen_t(MemoryLayout<timeval>.size)
        )
    }

    private static func writeResponseAndClose(
        clientFD: Int32,
        status: Int,
        reason: String,
        body: String
    ) {
        OAuthHTTPResponseWriter.writeResponse(
            clientFD: clientFD,
            status: status,
            reason: reason,
            body: body
        )
        close(clientFD)
    }
}
