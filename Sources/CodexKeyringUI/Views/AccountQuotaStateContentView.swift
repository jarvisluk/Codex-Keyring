import SwiftUI
import CodexKeyringDomain

struct AccountQuotaStateContentView: View {
    let state: AccountQuotaState

    var body: some View {
        content
    }

    @ViewBuilder
    private var content: some View {
        switch state.phase {
        case .loading:
            HStack(spacing: KeyringStyle.Spacing.small) {
                ProgressView()
                    .controlSize(.small)
                Text("Refreshing quota...")
                    .foregroundStyle(.secondary)
            }
        case .unsupported, .error:
            Label(state.message ?? state.health.label, systemImage: state.health.systemImage)
                .foregroundStyle(state.health.tint)
        case .available, .idle:
            if let snapshot = state.snapshot {
                AccountQuotaSnapshotView(snapshot: snapshot)
            } else {
                Text(state.message ?? "Quota unavailable.")
                    .foregroundStyle(.secondary)
            }
        }
    }
}
