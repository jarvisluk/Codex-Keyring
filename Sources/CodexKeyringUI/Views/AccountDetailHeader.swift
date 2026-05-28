import SwiftUI
import CodexKeyringDomain

struct AccountDetailHeader: View {
    let account: CodexAccount
    let isActive: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: KeyringStyle.Spacing.small) {
            HStack(alignment: .firstTextBaseline, spacing: KeyringStyle.Spacing.compact) {
                Text(account.displayName)
                    .font(.title.bold())
                    .lineLimit(2)
                    .truncationMode(.middle)
                    .layoutPriority(1)

                if isActive {
                    Label("Active", systemImage: "checkmark.circle.fill")
                        .labelStyle(.titleAndIcon)
                        .foregroundStyle(.green)
                        .font(.callout.weight(.semibold))
                }
            }

            Text(account.displayEmail)
                .font(.title3)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }
}
