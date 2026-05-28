import Foundation

extension LoginNewAccountUseCase {
    func tryRestorePreviousLiveAuth(from stagedURL: URL?) async -> Bool {
        do {
            try await installer.restoreLiveAuth(from: stagedURL)
            return true
        } catch {
            return false
        }
    }

    func cleanupStagedAuthFiles(_ urls: [URL?]) async -> String? {
        var failures: [String] = []
        for url in urls.compactMap({ $0 }) {
            do {
                try await installer.removeStagedAuth(url)
            } catch {
                failures.append("\(url.path): \(error.localizedDescription)")
            }
        }
        guard !failures.isEmpty else { return nil }
        return failures.joined(separator: "; ")
    }
}
