import Darwin
import Foundation

enum OAuthCallbackSocketBinder {
    static func bind(port requestedPort: UInt16) throws -> (Int32, UInt16) {
        let fd = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP)
        guard fd >= 0 else {
            throw OAuthCallbackServer.ServerError.bindFailed("socket() failed: \(posixDescription(errno))")
        }

        var reuse: Int32 = 1
        _ = setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &reuse, socklen_t(MemoryLayout.size(ofValue: reuse)))
        _ = fcntl(fd, F_SETFD, FD_CLOEXEC)
        let flags = fcntl(fd, F_GETFL, 0)
        guard flags >= 0, fcntl(fd, F_SETFL, flags | O_NONBLOCK) == 0 else {
            let reason = posixDescription(errno)
            close(fd)
            throw OAuthCallbackServer.ServerError.bindFailed("fcntl(O_NONBLOCK) failed: \(reason)")
        }

        var addr = sockaddr_in()
        addr.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = requestedPort.bigEndian
        addr.sin_addr.s_addr = inet_addr("127.0.0.1")

        let bindResult = withUnsafePointer(to: &addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sa in
                Darwin.bind(fd, sa, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        if bindResult != 0 {
            let reason = posixDescription(errno)
            close(fd)
            throw OAuthCallbackServer.ServerError.bindFailed("bind(127.0.0.1:\(requestedPort)) failed: \(reason)")
        }

        if listen(fd, 16) != 0 {
            let reason = posixDescription(errno)
            close(fd)
            throw OAuthCallbackServer.ServerError.bindFailed("listen() failed: \(reason)")
        }

        var actual = sockaddr_in()
        var len = socklen_t(MemoryLayout<sockaddr_in>.size)
        _ = withUnsafeMutablePointer(to: &actual) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sa in
                getsockname(fd, sa, &len)
            }
        }
        let port = UInt16(bigEndian: actual.sin_port)
        return (fd, port == 0 ? requestedPort : port)
    }
}
