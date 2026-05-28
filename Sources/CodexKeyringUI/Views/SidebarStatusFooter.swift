import SwiftUI

struct SidebarStatusFooter: View {
    @EnvironmentObject private var store: AccountStore

    private var presentation: SidebarStatusPresentation {
        SidebarStatusPresentation(
            statusMessage: store.statusMessage,
            lastError: store.lastError,
            isBusy: store.isStatusBusy
        )
    }

    var body: some View {
        HStack(alignment: .top, spacing: KeyringStyle.Spacing.note) {
            switch presentation.indicator {
            case .error:
                Image(systemName: presentation.indicator.systemImage ?? "")
                    .foregroundStyle(presentation.textTint.color)
                    .frame(width: KeyringStyle.Icon.statusSize, height: KeyringStyle.Icon.statusSize)
            case .busy:
                ProgressView()
                    .controlSize(.small)
                    .frame(width: KeyringStyle.Icon.statusSize, height: KeyringStyle.Icon.statusSize)
            case .none:
                EmptyView()
            }

            Text(presentation.message)
                .font(.caption)
                .foregroundStyle(presentation.textTint.color)
                .lineLimit(presentation.lineLimit)
                .textSelection(.enabled)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .help(presentation.help)
        .accessibilityLabel(presentation.accessibilityLabel)
    }
}
