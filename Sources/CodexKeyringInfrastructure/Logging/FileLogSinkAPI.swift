import Foundation

extension FileLogSink {
    public var currentFileURL: URL {
        files.currentFileURL
    }

    /// Asynchronously append a record to the current log file.
    public func write(_ record: LogRecord) {
        let line = formatter.format(record)
        queue.async { [weak self] in
            self?.writeOnQueue(line)
        }
    }

    /// Flush any buffered writes to disk; safe to call from any thread.
    public func flush() {
        queue.sync {
            try? self.handle?.synchronize()
        }
    }

    /// Returns the ordered list of log files: current first, then `.1`, `.2`, ...
    public func snapshotFileURLs() -> [URL] {
        var urls: [URL] = []
        queue.sync {
            urls = self.files.collectExistingURLs()
        }
        return urls
    }

    /// Combine every retained log file (oldest first) into a single text
    /// document at `destination`. An optional `header` is prepended.
    public func exportCombined(to destination: URL, header: String? = nil) throws {
        try FileLogExportWriter(
            destination: destination,
            header: header,
            orderedFiles: exportSnapshot(),
            protectedLogFileURLs: files.protectedURLs(),
            fileManager: fileManager
        ).write()
    }

    /// Remove every retained log file. Used by tests; not exposed to UI.
    public func reset() {
        queue.sync {
            try? self.handle?.close()
            self.handle = nil
            self.currentSize = 0
            for url in self.files.collectExistingURLs() {
                try? self.fileManager.removeItem(at: url)
            }
        }
    }
}
