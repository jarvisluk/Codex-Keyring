import Darwin
import Foundation

extension LiveAuthFileWatcher {
    func attach() {
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

    func currentSourceEvents() -> DispatchSource.FileSystemEvent {
        stateLock.lock()
        let src = source
        stateLock.unlock()
        return src?.data ?? DispatchSource.FileSystemEvent()
    }

    func cancelCurrentSource() {
        stateLock.lock()
        let existingSource = source
        source = nil
        fileDescriptor = -1
        stateLock.unlock()
        existingSource?.cancel()
    }
}
