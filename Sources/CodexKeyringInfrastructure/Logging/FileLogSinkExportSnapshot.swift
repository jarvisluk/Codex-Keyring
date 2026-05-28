import Foundation

extension FileLogSink {
    func exportSnapshot() throws -> [FileLogExportFile] {
        var orderedFiles: [FileLogExportFile] = []
        var captured: Error?
        queue.sync {
            do {
                try self.flushOnQueue()
                orderedFiles = try self.files.collectExistingURLs().reversed().map { url in
                    do {
                        return FileLogExportFile(url: url, data: try Data(contentsOf: url))
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
        return orderedFiles
    }

    func flushOnQueue() throws {
        try handle?.synchronize()
    }
}
