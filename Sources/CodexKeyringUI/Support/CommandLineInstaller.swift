import CodexKeyringDomain
import Darwin
import Foundation

struct CommandLineInstallResult: Equatable {
    let destinationPath: String
}

struct CommandLineUninstallResult: Equatable {
    let destinationPath: String
    let didRemove: Bool
}

enum CommandLineInstaller {
    static let commandName = "ckr"

    static var defaultDestinationURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".local", isDirectory: true)
            .appendingPathComponent("bin", isDirectory: true)
            .appendingPathComponent(commandName)
    }

    static func installFromBundle(
        bundle: Bundle = .main,
        destinationURL: URL = defaultDestinationURL,
        fileManager: FileManager = .default
    ) throws -> CommandLineInstallResult {
        guard let sourceURL = bundledCommandURL(bundle: bundle, fileManager: fileManager) else {
            throw CodexKeyringError.fileSystemFailure(
                reason: "Could not find the bundled ckr command in this app build."
            )
        }

        return try install(
            sourceURL: sourceURL,
            destinationURL: destinationURL,
            fileManager: fileManager
        )
    }

    static func install(
        sourceURL: URL,
        destinationURL: URL,
        fileManager: FileManager = .default
    ) throws -> CommandLineInstallResult {
        try requireExecutableSource(at: sourceURL, fileManager: fileManager)

        let destinationDirectory = destinationURL.deletingLastPathComponent()
        do {
            try fileManager.createDirectory(
                at: destinationDirectory,
                withIntermediateDirectories: true
            )
        } catch {
            throw CodexKeyringError.fileSystemFailure(
                reason: "Could not prepare \(destinationDirectory.path): \(error.localizedDescription)"
            )
        }

        let temporaryURL = destinationDirectory
            .appendingPathComponent(".\(destinationURL.lastPathComponent).tmp-\(UUID().uuidString)")
        do {
            if fileManager.fileExists(atPath: temporaryURL.path) {
                try fileManager.removeItem(at: temporaryURL)
            }
            try fileManager.copyItem(at: sourceURL, to: temporaryURL)
            try makeExecutable(temporaryURL, fileManager: fileManager)

            if fileManager.fileExists(atPath: destinationURL.path) {
                _ = try fileManager.replaceItemAt(destinationURL, withItemAt: temporaryURL)
            } else {
                try fileManager.moveItem(at: temporaryURL, to: destinationURL)
            }

            try makeExecutable(destinationURL, fileManager: fileManager)
        } catch {
            try? fileManager.removeItem(at: temporaryURL)
            throw CodexKeyringError.fileSystemFailure(
                reason: "Could not install ckr to \(destinationURL.path): \(error.localizedDescription)"
            )
        }

        return CommandLineInstallResult(destinationPath: destinationURL.path)
    }

    static func uninstall(
        destinationURL: URL = defaultDestinationURL,
        fileManager: FileManager = .default
    ) throws -> CommandLineUninstallResult {
        var isDirectory = ObjCBool(false)
        guard fileManager.fileExists(atPath: destinationURL.path, isDirectory: &isDirectory) else {
            return CommandLineUninstallResult(destinationPath: destinationURL.path, didRemove: false)
        }

        guard !isDirectory.boolValue else {
            throw CodexKeyringError.fileSystemFailure(
                reason: "Could not uninstall ckr because \(destinationURL.path) is a directory."
            )
        }

        do {
            try fileManager.removeItem(at: destinationURL)
        } catch {
            throw CodexKeyringError.fileSystemFailure(
                reason: "Could not uninstall ckr from \(destinationURL.path): \(error.localizedDescription)"
            )
        }

        return CommandLineUninstallResult(destinationPath: destinationURL.path, didRemove: true)
    }

    private static func bundledCommandURL(bundle: Bundle, fileManager: FileManager) -> URL? {
        let candidates = [
            bundle.resourceURL?.appendingPathComponent(commandName),
            bundle.executableURL?.deletingLastPathComponent().appendingPathComponent(commandName)
        ]
        return candidates.compactMap { $0 }.first { url in
            fileManager.isExecutableFile(atPath: url.path)
        }
    }

    private static func requireExecutableSource(at url: URL, fileManager: FileManager) throws {
        var isDirectory = ObjCBool(false)
        guard fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory),
              !isDirectory.boolValue
        else {
            throw CodexKeyringError.fileSystemFailure(
                reason: "Could not find ckr at \(url.path)."
            )
        }
        guard fileManager.isExecutableFile(atPath: url.path) else {
            throw CodexKeyringError.fileSystemFailure(
                reason: "ckr is not executable at \(url.path)."
            )
        }
    }

    private static func makeExecutable(_ url: URL, fileManager: FileManager) throws {
        try fileManager.setAttributes(
            [.posixPermissions: NSNumber(value: Int16(0o755))],
            ofItemAtPath: url.path
        )
    }
}
