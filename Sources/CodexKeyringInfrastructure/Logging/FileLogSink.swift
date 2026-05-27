import Foundation

/// Persisted log entry written to the rolling log file.
public struct LogRecord: Sendable {
    public enum Level: String, Sendable {
        case debug   = "DEBUG"
        case info    = "INFO"
        case notice  = "NOTE"
        case warning = "WARN"
        case error   = "ERROR"
        case fault   = "FAULT"
    }

    public let timestamp: Date
    public let category: String
    public let level: Level
    public let message: String

    public init(timestamp: Date = Date(), category: String, level: Level, message: String) {
        self.timestamp = timestamp
        self.category = category
        self.level = level
        self.message = message
    }
}

/// Thread-safe, rotating, append-only file log writer.
///
/// All file IO is funnelled through a single serial dispatch queue so writes
/// from any thread (including the OAuth socket queues) cannot interleave.
/// When the current file exceeds `maxFileBytes`, it is rotated to
/// `<name>.1`, with older generations shifted up to `<name>.maxFiles-1`.
public final class FileLogSink: @unchecked Sendable {
    public let directory: URL
    public let fileName: String
    public let maxFileBytes: Int
    public let maxFiles: Int

    private let queue: DispatchQueue
    private let fileManager: FileManager
    private let formatter: ISO8601DateFormatter

    private var handle: FileHandle?
    private var currentSize: Int = 0

    public init(
        directory: URL,
        fileName: String = AppPaths.logFileName,
        maxFileBytes: Int = 256_000,
        maxFiles: Int = 5,
        queue: DispatchQueue = DispatchQueue(
            label: "com.junrong.CodexKeyring.fileLogSink",
            qos: .utility
        ),
        fileManager: FileManager = .default
    ) {
        self.directory = directory
        self.fileName = fileName
        self.maxFileBytes = max(4_096, maxFileBytes)
        self.maxFiles = max(1, maxFiles)
        self.queue = queue
        self.fileManager = fileManager
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        self.formatter = formatter
    }

    public var currentFileURL: URL {
        directory.appendingPathComponent(fileName)
    }

    /// Asynchronously append a record to the current log file.
    public func write(_ record: LogRecord) {
        let line = format(record)
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
            urls = self.collectFileURLs()
        }
        return urls
    }

    /// Combine every retained log file (oldest first) into a single text
    /// document at `destination`. An optional `header` is prepended.
    public func exportCombined(to destination: URL, header: String? = nil) throws {
        var orderedFiles: [(url: URL, data: Data)] = []
        var captured: Error?
        queue.sync {
            do {
                try self.flushOnQueue()
                // Oldest first, current last so the export reads chronologically.
                // Read while holding the serial log queue so rotation cannot move
                // files between path collection and export snapshot creation.
                orderedFiles = try self.collectFileURLs().reversed().map { url in
                    do {
                        return (url, try Data(contentsOf: url))
                    } catch {
                        throw FileLogSinkError.exportFailed(
                            reason: "Could not read \(url.path): \(error.localizedDescription)"
                        )
                    }
                }
            } catch {
                captured = error
            }
        }
        if let captured { throw captured }

        let destinationPath = destination.standardizedFileURL.path
        let protectedLogPaths = Set(protectedLogFileURLs().map { $0.standardizedFileURL.path })
        guard !protectedLogPaths.contains(destinationPath) else {
            throw FileLogSinkError.exportFailed(
                reason: "Choose a destination outside Codex Keyring's active log files."
            )
        }

        var isDirectory = ObjCBool(false)
        if fileManager.fileExists(atPath: destination.path, isDirectory: &isDirectory) {
            guard !isDirectory.boolValue else {
                throw FileLogSinkError.exportFailed(reason: "Choose a file destination, not a directory.")
            }
        }
        let temporaryDestination = destination
            .deletingLastPathComponent()
            .appendingPathComponent(".\(destination.lastPathComponent).tmp-\(UUID().uuidString)")
        try fileManager.createDirectory(
            at: destination.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        do {
            guard fileManager.createFile(atPath: temporaryDestination.path, contents: nil) else {
                throw FileLogSinkError.exportFailed(reason: "Could not create \(destination.path).")
            }
            try PrivateFilePermissions.setFile(at: temporaryDestination, fileManager: fileManager)
            let outHandle = try FileHandle(forWritingTo: temporaryDestination)
            do {
                if let header, !header.isEmpty {
                    try outHandle.write(contentsOf: Data(header.utf8))
                }

                for (_, data) in orderedFiles {
                    guard !data.isEmpty else { continue }
                    try outHandle.write(contentsOf: data)
                    if data.last != 0x0A {
                        try outHandle.write(contentsOf: Data([0x0A]))
                    }
                }
                try outHandle.close()
            } catch {
                try? outHandle.close()
                throw error
            }

            if fileManager.fileExists(atPath: destination.path) {
                _ = try fileManager.replaceItemAt(destination, withItemAt: temporaryDestination)
            } else {
                try fileManager.moveItem(at: temporaryDestination, to: destination)
            }
            try PrivateFilePermissions.setFile(at: destination, fileManager: fileManager)
        } catch {
            try? fileManager.removeItem(at: temporaryDestination)
            throw error
        }
    }

    /// Remove every retained log file. Used by tests; not exposed to UI.
    public func reset() {
        queue.sync {
            try? self.handle?.close()
            self.handle = nil
            self.currentSize = 0
            for url in self.collectFileURLs() {
                try? self.fileManager.removeItem(at: url)
            }
        }
    }

    // MARK: - Queue-only helpers

    private func format(_ record: LogRecord) -> String {
        let ts = formatter.string(from: record.timestamp)
        let level = record.level.rawValue.padding(toLength: 5, withPad: " ", startingAt: 0)
        let category = record.category.padding(toLength: 14, withPad: " ", startingAt: 0)
        let safeMessage = record.message
            .replacingOccurrences(of: "\r\n", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
        return "\(ts) [\(level)] \(category) \(safeMessage)\n"
    }

    private func writeOnQueue(_ line: String) {
        do {
            try ensureHandleOnQueue()
            let data = Data(line.utf8)
            if currentSize + data.count > maxFileBytes {
                try rotateOnQueue()
                try ensureHandleOnQueue()
            }
            try handle?.write(contentsOf: data)
            currentSize += data.count
        } catch {
            // Logging must not crash the app; swallow IO errors to avoid feedback loops.
        }
    }

    private func ensureHandleOnQueue() throws {
        if handle != nil { return }
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        try PrivateFilePermissions.setDirectory(at: directory, fileManager: fileManager)
        let url = currentFileURL
        if !fileManager.fileExists(atPath: url.path) {
            fileManager.createFile(atPath: url.path, contents: nil)
        }
        try PrivateFilePermissions.setFile(at: url, fileManager: fileManager)
        let handle = try FileHandle(forWritingTo: url)
        try handle.seekToEnd()
        currentSize = Int(try handle.offset())
        self.handle = handle
    }

    private func flushOnQueue() throws {
        try handle?.synchronize()
    }

    private func rotateOnQueue() throws {
        try handle?.close()
        handle = nil
        currentSize = 0

        let oldestIndex = maxFiles - 1
        if oldestIndex >= 1 {
            let oldest = directory.appendingPathComponent("\(fileName).\(oldestIndex)")
            if fileManager.fileExists(atPath: oldest.path) {
                try fileManager.removeItem(at: oldest)
            }
            for i in stride(from: oldestIndex - 1, through: 1, by: -1) {
                let from = directory.appendingPathComponent("\(fileName).\(i)")
                let to = directory.appendingPathComponent("\(fileName).\(i + 1)")
                if fileManager.fileExists(atPath: from.path) {
                    if fileManager.fileExists(atPath: to.path) {
                        try fileManager.removeItem(at: to)
                    }
                    try fileManager.moveItem(at: from, to: to)
                    try PrivateFilePermissions.setFile(at: to, fileManager: fileManager)
                }
            }
        }

        let current = currentFileURL
        if fileManager.fileExists(atPath: current.path) {
            if maxFiles > 1 {
                let to = directory.appendingPathComponent("\(fileName).1")
                if fileManager.fileExists(atPath: to.path) {
                    try fileManager.removeItem(at: to)
                }
                try fileManager.moveItem(at: current, to: to)
                try PrivateFilePermissions.setFile(at: to, fileManager: fileManager)
            } else {
                try fileManager.removeItem(at: current)
            }
        }
    }

    private func collectFileURLs() -> [URL] {
        var urls: [URL] = []
        let current = currentFileURL
        if fileManager.fileExists(atPath: current.path) {
            urls.append(current)
        }
        for i in 1..<maxFiles {
            let url = directory.appendingPathComponent("\(fileName).\(i)")
            if fileManager.fileExists(atPath: url.path) {
                urls.append(url)
            }
        }
        return urls
    }

    private func protectedLogFileURLs() -> [URL] {
        [currentFileURL] + (1..<maxFiles).map { index in
            directory.appendingPathComponent("\(fileName).\(index)")
        }
    }
}

public enum FileLogSinkError: LocalizedError, Equatable {
    case exportFailed(reason: String)

    public var errorDescription: String? {
        switch self {
        case .exportFailed(let reason):
            return "Could not export logs: \(reason)"
        }
    }
}
