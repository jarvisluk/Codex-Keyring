import SwiftUI
import CodexKeyringDomain

struct AccountDetailMetadataGrid: View {
    @Environment(\.accountSensitiveValuesVisible) private var showsAccountSensitiveValues

    let account: CodexAccount

    var body: some View {
        let details = AccountDetailMetadataPresentation(account: account)
        Grid(
            alignment: .leading,
            horizontalSpacing: KeyringStyle.Grid.metadataHorizontalSpacing,
            verticalSpacing: KeyringStyle.Grid.locationVerticalSpacing
        ) {
            detailRow("Auth mode", details.authMode)
            detailRow("Plan", details.plan)
            detailRow("Account ID", details.accountIdentifier, isSensitive: true)
            detailRow("Fingerprint", details.fingerprint, isSensitive: true)
            detailRow("Saved", formatDate(account.createdAt))
            detailRow("Updated", formatDate(account.updatedAt))
            if let expiry = account.tokenExpiresAt {
                detailRow("Token expires", formatDate(expiry))
            }
        }
        .keyringSurface(.regular)
    }

    private func formatDate(_ date: Date) -> String {
        date.formatted(date: .abbreviated, time: .shortened)
    }

    private func detailRow(
        _ title: String,
        _ value: String,
        isSensitive: Bool = false
    ) -> some View {
        GridRow {
            Text(title)
                .foregroundStyle(.secondary)
            if isSensitive {
                AccountSensitiveValueText(value, revealed: showsAccountSensitiveValues)
                    .textSelection(.enabled)
                    .lineLimit(2)
                    .truncationMode(.middle)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text(value)
                    .textSelection(.enabled)
                    .lineLimit(2)
                    .truncationMode(.middle)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
