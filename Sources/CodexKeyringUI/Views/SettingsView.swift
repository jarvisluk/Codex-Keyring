import SwiftUI
import CodexKeyringInfrastructure

public struct SettingsView: View {
    @EnvironmentObject private var store: AccountStore

    public init() {}

    public var body: some View {
        Form {
            Toggle("Restart Codex App after switching", isOn: Binding(
                get: { store.settings.restartCodexAppAfterSwitch },
                set: { store.settings.restartCodexAppAfterSwitch = $0 }
            ))

            Toggle("Launch at login", isOn: Binding(
                get: { store.settings.launchAtLogin },
                set: { store.setLaunchAtLogin($0) }
            ))
            .disabled(!LaunchAtLoginController.isSupported)

            Toggle("Allow network quota/account API calls", isOn: Binding(
                get: { store.settings.allowNetworkQuotaAPIs },
                set: { store.settings.allowNetworkQuotaAPIs = $0 }
            ))
            .disabled(true)

            Text("Network quota APIs are intentionally disabled in this first version. Account switching works only with local Codex auth files.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Divider()

            LabeledContent("Codex auth") {
                Text(AppPaths.codexAuthFile.path)
                    .textSelection(.enabled)
            }

            LabeledContent("App data") {
                Text(AppPaths.applicationSupportDirectory.path)
                    .textSelection(.enabled)
            }
        }
        .padding(24)
        .frame(width: 560)
    }
}
