import Foundation

struct FileLogFileSet {
    let directory: URL
    let fileName: String
    let maxFiles: Int
    let fileManager: FileManager

    var currentFileURL: URL {
        directory.appendingPathComponent(fileName)
    }

    func collectExistingURLs() -> [URL] {
        var urls: [URL] = []
        let current = currentFileURL
        if fileManager.fileExists(atPath: current.path) {
            urls.append(current)
        }
        for index in 1..<maxFiles {
            let url = retainedURL(index: index)
            if fileManager.fileExists(atPath: url.path) {
                urls.append(url)
            }
        }
        return urls
    }

    func protectedURLs() -> [URL] {
        [currentFileURL] + (1..<maxFiles).map(retainedURL(index:))
    }

    func rotate() throws {
        let oldestIndex = maxFiles - 1
        if oldestIndex >= 1 {
            let oldest = retainedURL(index: oldestIndex)
            if fileManager.fileExists(atPath: oldest.path) {
                try fileManager.removeItem(at: oldest)
            }
            for index in stride(from: oldestIndex - 1, through: 1, by: -1) {
                try moveRetainedFile(fromIndex: index, toIndex: index + 1)
            }
        }

        let current = currentFileURL
        guard fileManager.fileExists(atPath: current.path) else { return }
        if maxFiles > 1 {
            let destination = retainedURL(index: 1)
            if fileManager.fileExists(atPath: destination.path) {
                try fileManager.removeItem(at: destination)
            }
            try fileManager.moveItem(at: current, to: destination)
            try PrivateFilePermissions.setFile(at: destination, fileManager: fileManager)
        } else {
            try fileManager.removeItem(at: current)
        }
    }

    private func retainedURL(index: Int) -> URL {
        directory.appendingPathComponent("\(fileName).\(index)")
    }

    private func moveRetainedFile(fromIndex: Int, toIndex: Int) throws {
        let source = retainedURL(index: fromIndex)
        guard fileManager.fileExists(atPath: source.path) else { return }

        let destination = retainedURL(index: toIndex)
        if fileManager.fileExists(atPath: destination.path) {
            try fileManager.removeItem(at: destination)
        }
        try fileManager.moveItem(at: source, to: destination)
        try PrivateFilePermissions.setFile(at: destination, fileManager: fileManager)
    }
}
