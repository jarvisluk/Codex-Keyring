import SwiftUI

struct AddCurrentAuthSummaryView: View {
    let summary: AddCurrentAccountSummary

    var body: some View {
        Grid(
            alignment: .leading,
            horizontalSpacing: KeyringStyle.Grid.compactHorizontalSpacing,
            verticalSpacing: KeyringStyle.Grid.compactVerticalSpacing
        ) {
            summaryRow("Email", summary.email)
            summaryRow("Plan", summary.plan)
            summaryRow("Auth", summary.authMode)
            summaryRow("Fingerprint", summary.fingerprint)
        }
        .keyringSurface(.thin, padding: KeyringStyle.Spacing.section)
    }

    private func summaryRow(_ title: String, _ value: String) -> some View {
        GridRow {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .lineLimit(1)
                .truncationMode(.middle)
                .textSelection(.enabled)
        }
    }
}
