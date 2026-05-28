import Foundation

struct FileLogExportFile {
    let url: URL
    let data: Data
}

struct FileLogExportWriter {
    let destination: URL
    let header: String?
    let orderedFiles: [FileLogExportFile]
    let protectedLogFileURLs: [URL]
    let fileManager: FileManager

    func write() throws {
        try FileLogExportDestinationValidator(
            destination: destination,
            protectedLogFileURLs: protectedLogFileURLs,
            fileManager: fileManager
        ).validate()

        let temporaryDestination = destination
            .deletingLastPathComponent()
            .appendingPathComponent(".\(destination.lastPathComponent).tmp-\(UUID().uuidString)")
        try fileManager.createDirectory(
            at: destination.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        do {
            try writeExport(to: temporaryDestination)
            try installExport(from: temporaryDestination)
        } catch {
            try? fileManager.removeItem(at: temporaryDestination)
            throw error
        }
    }

    private func writeExport(to temporaryDestination: URL) throws {
        guard fileManager.createFile(atPath: temporaryDestination.path, contents: nil) else {
            throw FileLogSinkError.exportFailed(reason: "Could not create \(destination.path).")
        }
        try PrivateFilePermissions.setFile(at: temporaryDestination, fileManager: fileManager)
        let outHandle = try FileHandle(forWritingTo: temporaryDestination)
        do {
            if let header, !header.isEmpty {
                try outHandle.write(contentsOf: Data(header.utf8))
            }

            for file in orderedFiles {
                guard !file.data.isEmpty else { continue }
                try outHandle.write(contentsOf: file.data)
                if file.data.last != 0x0A {
                    try outHandle.write(contentsOf: Data([0x0A]))
                }
            }
            try outHandle.close()
        } catch {
            try? outHandle.close()
            throw error
        }
    }

    private func installExport(from temporaryDestination: URL) throws {
        if fileManager.fileExists(atPath: destination.path) {
            _ = try fileManager.replaceItemAt(destination, withItemAt: temporaryDestination)
        } else {
            try fileManager.moveItem(at: temporaryDestination, to: destination)
        }
        try PrivateFilePermissions.setFile(at: destination, fileManager: fileManager)
    }
}
