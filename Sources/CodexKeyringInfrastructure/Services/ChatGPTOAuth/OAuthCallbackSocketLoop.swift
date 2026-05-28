import Darwin
import Foundation

typealias OAuthCallbackHandler = @Sendable ([URLQueryItem], Int32) -> Void

enum OAuthCallbackSocketLoop {
    static func run(
        listener: OAuthListenerState,
        connectionQueue: DispatchQueue,
        onCallback: @escaping OAuthCallbackHandler
    ) {
        let fd = listener.fd
        while true {
            if listener.isStopped { return }

            var descriptor = pollfd(fd: fd, events: Int16(POLLIN), revents: 0)
            let pollResult = Darwin.poll(&descriptor, 1, 100)
            if pollResult < 0 {
                if errno == EINTR { continue }
                return
            }
            if pollResult == 0 { continue }
            if listener.isStopped { return }
            if descriptor.revents & Int16(POLLNVAL | POLLERR | POLLHUP) != 0 {
                return
            }
            guard descriptor.revents & Int16(POLLIN) != 0 else {
                continue
            }

            while true {
                let clientFD = acceptClient(from: fd)
                if clientFD < 0 {
                    let captured = errno
                    if captured == EINTR { continue }
                    if captured == EAGAIN || captured == EWOULDBLOCK {
                        break
                    }
                    return
                }
                prepareClientDescriptor(clientFD)
                connectionQueue.async {
                    OAuthCallbackConnectionHandler.handle(
                        clientFD: clientFD,
                        onCallback: onCallback
                    )
                }
            }
        }
    }

    private static func acceptClient(from fd: Int32) -> Int32 {
        var clientAddr = sockaddr_in()
        var len = socklen_t(MemoryLayout<sockaddr_in>.size)
        return withUnsafeMutablePointer(to: &clientAddr) { ptr -> Int32 in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sa in
                Darwin.accept(fd, sa, &len)
            }
        }
    }

    private static func prepareClientDescriptor(_ clientFD: Int32) {
        _ = fcntl(clientFD, F_SETFD, FD_CLOEXEC)
        let clientFlags = fcntl(clientFD, F_GETFL, 0)
        if clientFlags >= 0 {
            _ = fcntl(clientFD, F_SETFL, clientFlags & ~O_NONBLOCK)
        }
    }
}
