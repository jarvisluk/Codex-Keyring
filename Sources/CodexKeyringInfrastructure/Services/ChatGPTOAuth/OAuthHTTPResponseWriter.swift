import Darwin
import Foundation

enum OAuthHTTPResponseWriter {
    static func writeResponse(
        clientFD: Int32,
        status: Int,
        reason: String,
        body: String,
        contentType: String = "text/plain; charset=utf-8"
    ) {
        let bodyData = Data(body.utf8)
        var header = "HTTP/1.1 \(status) \(reason)\r\n"
        header += "Content-Type: \(contentType)\r\n"
        header += "Content-Length: \(bodyData.count)\r\n"
        header += "Connection: close\r\n\r\n"
        var response = Data(header.utf8)
        response.append(bodyData)
        _ = response.withUnsafeBytes { ptr -> Int in
            guard let base = ptr.baseAddress else { return -1 }
            var sent = 0
            while sent < ptr.count {
                let written = Darwin.write(clientFD, base.advanced(by: sent), ptr.count - sent)
                if written <= 0 { return sent }
                sent += written
            }
            return sent
        }
    }
}
