import Foundation

extension FileLogSink {
    func writeOnQueue(_ line: String) {
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

    func ensureHandleOnQueue() throws {
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

    func rotateOnQueue() throws {
        try handle?.close()
        handle = nil
        currentSize = 0
        try files.rotate()
    }
}
