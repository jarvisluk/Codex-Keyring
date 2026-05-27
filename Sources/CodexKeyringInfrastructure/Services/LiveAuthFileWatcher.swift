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
    private let url: URL
    private let queue: DispatchQueue
    private let debounceInterval: DispatchTimeInterval
    private let reattachInterval: DispatchTimeInterval
    private let log = CodexKeyringLog.makeAppLogger(.liveAuth)

    private let stateLock = NSLock()
    private var source: DispatchSourceFileSystemObject?
    private var fileDescriptor: Int32 = -1
    private var reattachTimer: DispatchSourceTimer?
    private var debounceItem: DispatchWorkItem?
    private var changeHandler: (@Sendable () -> Void)?
    private var isRunning = false

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

    private func attach() {
        cancelCurrentSource()

        let fd = open(url.path, O_EVTONLY)
        if fd == -1 {
            scheduleReattach()
            return
        }

        let mask: DispatchSource.FileSystemEvent = [.write, .extend, .delete, .rename, .revoke, .link]
        let src = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: mask,
            queue: queue
        )

        src.setEventHandler { [weak self] in
            guard let self else { return }
            let events = self.currentSourceEvents()
            self.scheduleChange()
            if events.contains(.delete) || events.contains(.rename) || events.contains(.revoke) {
                self.log.debug("live auth file replaced; re-attaching watcher")
                self.attach()
            }
        }

        src.setCancelHandler { [fd] in
            close(fd)
        }

        stateLock.lock()
        fileDescriptor = fd
        source = src
        stateLock.unlock()

        src.resume()
        log.debug("watching live auth at \(url.path)")
        scheduleChange()
    }

    private func currentSourceEvents() -> DispatchSource.FileSystemEvent {
        stateLock.lock()
        let src = source
        stateLock.unlock()
        return src?.data ?? DispatchSource.FileSystemEvent()
    }

    private func scheduleReattach() {
        stateLock.lock()
        guard isRunning else {
            stateLock.unlock()
            return
        }
        reattachTimer?.cancel()
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + reattachInterval)
        timer.setEventHandler { [weak self] in
            self?.attach()
        }
        reattachTimer = timer
        stateLock.unlock()
        timer.resume()
    }

    private func scheduleChange() {
        stateLock.lock()
        guard isRunning, let handler = changeHandler else {
            stateLock.unlock()
            return
        }
        debounceItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.stateLock.lock()
            let stillRunning = self.isRunning
            self.stateLock.unlock()
            guard stillRunning else { return }
            handler()
        }
        debounceItem = work
        stateLock.unlock()
        queue.asyncAfter(deadline: .now() + debounceInterval, execute: work)
    }

    private func teardown() {
        cancelCurrentSource()
        stateLock.lock()
        reattachTimer?.cancel()
        reattachTimer = nil
        debounceItem?.cancel()
        debounceItem = nil
        stateLock.unlock()
    }

    private func cancelCurrentSource() {
        stateLock.lock()
        let existingSource = source
        source = nil
        fileDescriptor = -1
        stateLock.unlock()
        existingSource?.cancel()
    }
}
