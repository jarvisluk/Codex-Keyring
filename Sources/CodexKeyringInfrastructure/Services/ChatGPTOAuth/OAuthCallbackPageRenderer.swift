import Foundation

enum OAuthCallbackPageRenderer {
    static func renderSuccessPage(clientFD: Int32) {
        let body = """
        <!doctype html>
        <html><head><meta charset="utf-8"><title>Sign-in complete</title>
        <style>
        body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif; background: #0b0b0c; color: #f5f5f7; display: flex; align-items: center; justify-content: center; height: 100vh; margin: 0; }
        .card { max-width: 420px; padding: 32px; background: #1c1c1f; border-radius: 16px; box-shadow: 0 10px 30px rgba(0,0,0,0.4); text-align: center; }
        h1 { font-size: 22px; margin: 0 0 12px; }
        p { color: #c7c7cc; line-height: 1.5; margin: 0; }
        </style></head>
        <body><div class="card"><h1>Signed in to ChatGPT</h1><p>You can close this window and return to Codex Keyring.</p></div></body></html>
        """
        OAuthHTTPResponseWriter.writeResponse(
            clientFD: clientFD,
            status: 200,
            reason: "OK",
            body: body,
            contentType: "text/html; charset=utf-8"
        )
    }

    static func renderErrorPage(clientFD: Int32, message: String) {
        let escaped = message
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
        let body = """
        <!doctype html>
        <html><head><meta charset="utf-8"><title>Sign-in failed</title>
        <style>
        body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif; background: #1a0b0b; color: #f5f5f7; display: flex; align-items: center; justify-content: center; height: 100vh; margin: 0; }
        .card { max-width: 480px; padding: 32px; background: #2a1010; border-radius: 16px; box-shadow: 0 10px 30px rgba(0,0,0,0.4); text-align: center; }
        h1 { font-size: 22px; margin: 0 0 12px; color: #ff6b6b; }
        p { color: #f4d6d6; line-height: 1.5; margin: 0; word-break: break-word; }
        </style></head>
        <body><div class="card"><h1>Sign-in failed</h1><p>\(escaped)</p></div></body></html>
        """
        OAuthHTTPResponseWriter.writeResponse(
            clientFD: clientFD,
            status: 400,
            reason: "Bad Request",
            body: body,
            contentType: "text/html; charset=utf-8"
        )
    }
}
