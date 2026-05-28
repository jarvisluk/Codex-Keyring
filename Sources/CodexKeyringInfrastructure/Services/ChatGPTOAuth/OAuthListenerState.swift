import Darwin
import Foundation

final class OAuthListenerState: @unchecked Sendable {
    let fd: Int32

    private let lock = NSLock()
    private var stopped = false

    init(fd: Int32) {
        self.fd = fd
    }

    var isStopped: Bool {
        lock.lock()
        defer { lock.unlock() }
        return stopped
    }

    func stop() {
        lock.lock()
        guard !stopped else {
            lock.unlock()
            return
        }
        stopped = true
        lock.unlock()

        _ = Darwin.shutdown(fd, SHUT_RDWR)
        _ = Darwin.close(fd)
    }
}

func posixDescription(_ code: Int32) -> String {
    String(cString: strerror(code))
}
