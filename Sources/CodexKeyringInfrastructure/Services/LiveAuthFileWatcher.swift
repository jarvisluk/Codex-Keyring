import Foundation
import CodexKeyringDomain

/// `LiveAuthWatching` backed by `DispatchSource.makeFileSystemObjectSource`.
///
/// `~/.codex/auth.json` is typically written via `replaceItemAt`-style atomic
/// rename, which invalidates the previously held file descriptor. The watcher
/// reacts to `.delete | .rename | .revoke` by re-opening the file. If the
/// file is briefly absent (or never existed yet), a short polling loop tries
/// to reattach until it shows up.
public final class LiveAuthFileWatcher: LiveAuthWatching, @unchecked Sendable {
    let url: URL
    let queue: DispatchQueue
    let debounceInterval: DispatchTimeInterval
    let reattachInterval: DispatchTimeInterval
    let log = CodexKeyringLog.makeAppLogger(.liveAuth)

    let stateLock = NSLock()
    var source: DispatchSourceFileSystemObject?
    var fileDescriptor: Int32 = -1
    var reattachTimer: DispatchSourceTimer?
    var debounceItem: DispatchWorkItem?
    var changeHandler: (@Sendable () -> Void)?
    var isRunning = false

    public init(
        url: URL = AppPaths.codexAuthFile,
        queue: DispatchQueue = DispatchQueue(label: "com.junrong.CodexKeyring.LiveAuthFileWatcher"),
        debounceInterval: DispatchTimeInterval = .milliseconds(250),
        reattachInterval: DispatchTimeInterval = .seconds(2)
    ) {
        self.url = url
        self.queue = queue
        self.debounceInterval = debounceInterval
        self.reattachInterval = reattachInterval
    }

    deinit {
        teardown()
    }

    public func start(onChange handler: @escaping @Sendable () -> Void) {
        stateLock.lock()
        if isRunning {
            changeHandler = handler
            stateLock.unlock()
            return
        }
        isRunning = true
        changeHandler = handler
        stateLock.unlock()
        queue.async { [weak self] in
            self?.attach()
        }
    }

    public func stop() {
        stateLock.lock()
        guard isRunning else {
            stateLock.unlock()
            return
        }
        isRunning = false
        let handler = changeHandler
        changeHandler = nil
        stateLock.unlock()
        queue.async { [weak self] in
            self?.teardown()
        }
        _ = handler
    }
}
