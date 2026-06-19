import SwiftUI

struct AddCurrentAuthSummaryView: View {
    @Environment(\.accountSensitiveValuesVisible) private var showsAccountSensitiveValues

    let summary: AddCurrentAccountSummary

    var body: some View {
        Grid(
            alignment: .leading,
            horizontalSpacing: KeyringStyle.Grid.compactHorizontalSpacing,
            verticalSpacing: KeyringStyle.Grid.compactVerticalSpacing
        ) {
            summaryRow("Email", summary.email, isSensitive: true)
            summaryRow("Plan", summary.plan)
            summaryRow("Auth", summary.authMode)
            summaryRow("Fingerprint", summary.fingerprint, isSensitive: true)
        }
        .keyringSurface(.thin, padding: KeyringStyle.Spacing.section)
    }

    private func summaryRow(
        _ title: String,
        _ value: String,
        isSensitive: Bool = false
    ) -> some View {
        GridRow {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            if isSensitive {
                AccountSensitiveValueText(value, revealed: showsAccountSensitiveValues)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .textSelection(.enabled)
            } else {
                Text(value)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .textSelection(.enabled)
            }
        }
    }
}
