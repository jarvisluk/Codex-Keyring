import AppKit
import Foundation

enum CodexAppController {
    static var isCodexAppRunning: Bool {
        !runningCodexApplications().isEmpty
    }

    static func restartCodexAppIfRunning() throws -> String {
        let running = runningCodexApplications()
        guard !running.isEmpty else {
            return "Codex App was not running; Codex CLI will use the switched account immediately."
        }

        for app in running {
            app.terminate()
        }

        for _ in 0..<30 {
            if runningCodexApplications().isEmpty {
                break
            }
            Thread.sleep(forTimeInterval: 0.15)
        }

        let codexAppURL = URL(fileURLWithPath: "/Applications/Codex.app", isDirectory: true)
        if FileManager.default.fileExists(atPath: codexAppURL.path) {
            let configuration = NSWorkspace.OpenConfiguration()
            configuration.activates = true
            NSWorkspace.shared.openApplication(at: codexAppURL, configuration: configuration)
            return "Codex App was restarted so it can reload the switched auth state."
        }

        return "Codex App was quit, but /Applications/Codex.app was not found for relaunch."
    }

    private static func runningCodexApplications() -> [NSRunningApplication] {
        NSWorkspace.shared.runningApplications.filter { app in
            app.bundleURL?.lastPathComponent == "Codex.app"
        }
    }
}
