import SwiftUI
import CodexKeyringDomain

struct AccountDetailHeader: View {
    @Environment(\.accountSensitiveValuesVisible) private var showsAccountSensitiveValues

    let account: CodexAccount
    let isActive: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: KeyringStyle.Spacing.small) {
            HStack(alignment: .firstTextBaseline, spacing: KeyringStyle.Spacing.compact) {
                AccountSensitiveValueText(
                    AccountSensitiveText.displayName(for: account, revealed: true),
                    revealed: showsAccountSensitiveValues,
                    displayValue: AccountSensitiveText.displayName(
                        for: account,
                        revealed: showsAccountSensitiveValues
                    )
                )
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

            AccountSensitiveValueText(
                AccountSensitiveText.displayEmail(for: account, revealed: true),
                revealed: showsAccountSensitiveValues,
                displayValue: AccountSensitiveText.displayEmail(
                    for: account,
                    revealed: showsAccountSensitiveValues
                )
            )
                .font(.title3)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }
}
