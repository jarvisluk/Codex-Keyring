import Foundation

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

    let queue: DispatchQueue
    let fileManager: FileManager
    let formatter: LogRecordFormatter
    let files: FileLogFileSet

    var handle: FileHandle?
    var currentSize: Int = 0

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
        self.formatter = LogRecordFormatter()
        self.files = FileLogFileSet(
            directory: directory,
            fileName: fileName,
            maxFiles: self.maxFiles,
            fileManager: fileManager
        )
    }
}
