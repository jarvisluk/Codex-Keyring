import SwiftUI
import CodexKeyringDomain

struct AccountQuotaWindowView: View {
    let window: QuotaWindow

    private var presentation: QuotaWindowPresentation {
        QuotaWindowPresentation(window: window)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: KeyringStyle.Spacing.inlineTight) {
            HStack {
                Text(presentation.durationLabel)
                Spacer()
                Text(presentation.remainingText)
                    .foregroundStyle(presentation.remainingTextTint.color)
            }
            .font(.caption)

            ProgressView(value: presentation.remainingPercent, total: 100)
                .tint(presentation.progressTint.color)

            Text(presentation.resetText)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}
