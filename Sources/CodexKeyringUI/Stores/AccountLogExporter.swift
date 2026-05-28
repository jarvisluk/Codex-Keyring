import Foundation
import CodexKeyringDomain

enum AccountLogExporter {
    static func export(
        logService: any AppLogService,
        to destination: URL,
        completion: @escaping @MainActor @Sendable (Result<URL, Error>) -> Void
    ) {
        logService.info("user requested log export to \(destination.lastPathComponent)")

        Task.detached(priority: .utility) {
            do {
                try logService.exportLogs(to: destination)
                logService.info("log export complete at \(destination.path)")
                await MainActor.run {
                    completion(.success(destination))
                }
            } catch {
                logService.error("log export failed: \(error.localizedDescription)")
                await MainActor.run {
                    completion(.failure(error))
                }
            }
        }
    }
}
