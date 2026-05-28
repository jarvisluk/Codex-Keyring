import Foundation

struct AddAccountInitialPreferences: Sendable {
    let preferences: AccountAgentPreferences?
    let warningReason: String?
}

extension AddAccountUseCase {
    func captureInitialPreferences(
        manifest: AccountManifest,
        sourceURL: URL,
        activate: Bool
    ) async -> AddAccountInitialPreferences {
        // Capture only when this add operation owns the live Codex state.
        guard manifest.settings.preserveAgentPreferencesPerAccount,
              activate,
              sourceURL == installer.liveAuthFileURL
        else {
            return AddAccountInitialPreferences(preferences: nil, warningReason: nil)
        }

        do {
            let captured = try await preferencesPort.captureCurrent()
            return AddAccountInitialPreferences(
                preferences: captured.isEmpty ? nil : captured,
                warningReason: nil
            )
        } catch {
            return AddAccountInitialPreferences(
                preferences: nil,
                warningReason: error.localizedDescription
            )
        }
    }
}
