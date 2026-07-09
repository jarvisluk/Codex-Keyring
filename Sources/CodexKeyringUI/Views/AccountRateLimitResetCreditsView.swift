import SwiftUI
import CodexKeyringDomain

struct AccountRateLimitResetCreditsView: View {
    let resetCredits: AccountRateLimitResetCredits

    private var presentation: RateLimitResetCreditsPresentation {
        RateLimitResetCreditsPresentation(resetCredits: resetCredits)
    }

    var body: some View {
        if presentation.isVisible {
            VStack(alignment: .leading, spacing: KeyringStyle.Spacing.compact) {
                Label(presentation.summaryText, systemImage: "arrow.counterclockwise.circle")
                    .font(.subheadline.weight(.semibold))

                VStack(alignment: .leading, spacing: KeyringStyle.Spacing.inlineTight) {
                    Text(presentation.expirationText)
                    if let exactExpirationText = presentation.exactExpirationText {
                        Text(exactExpirationText)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                if presentation.rows.count > 1 {
                    VStack(alignment: .leading, spacing: KeyringStyle.Spacing.note) {
                        ForEach(presentation.rows) { row in
                            VStack(alignment: .leading, spacing: KeyringStyle.Spacing.micro) {
                                HStack(alignment: .firstTextBaseline) {
                                    Text(row.title)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                    Spacer()
                                    Text(row.expirationText)
                                        .foregroundStyle(.secondary)
                                }

                                if let exactExpirationText = row.exactExpirationText {
                                    Text("Expires \(exactExpirationText)")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .font(.caption)
                        }
                    }
                }
            }
        }
    }
}
