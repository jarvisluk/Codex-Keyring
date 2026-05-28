import Foundation

extension LiveAuthFileWatcher {
    func scheduleReattach() {
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

    func scheduleChange() {
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

    func teardown() {
        cancelCurrentSource()
        stateLock.lock()
        reattachTimer?.cancel()
        reattachTimer = nil
        debounceItem?.cancel()
        debounceItem = nil
        stateLock.unlock()
    }
}
