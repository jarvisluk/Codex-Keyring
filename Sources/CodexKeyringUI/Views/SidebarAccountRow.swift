import SwiftUI
import CodexKeyringDomain

struct SidebarAccountRow: View {
    var account: CodexAccount
    var isActive: Bool
    var isSelected: Bool
    var quotaState: AccountQuotaState?

    private var presentation: SidebarAccountPresentation {
        SidebarAccountPresentation(
            account: account,
            isActive: isActive,
            isSelected: isSelected,
            quotaState: quotaState
        )
    }

    var body: some View {
        HStack(spacing: KeyringStyle.Spacing.compact) {
            Image(systemName: presentation.statusSystemImage)
                .foregroundStyle(presentation.statusIconTint.color)
                .frame(width: KeyringStyle.Icon.rowWidth)

            VStack(alignment: .leading, spacing: KeyringStyle.Spacing.micro) {
                Text(presentation.title)
                    .foregroundStyle(presentation.titleTint.color)
                    .lineLimit(1)
                    .truncationMode(.middle)
                detailLine
            }
        }
        .padding(.vertical, 3)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(presentation.accessibilitySummary)
    }

    private var detailLine: some View {
        HStack(spacing: KeyringStyle.Spacing.inlineTight) {
            Text(presentation.subtitle)
                .foregroundStyle(presentation.secondaryTextTint.color)
                .truncationMode(.middle)
                .layoutPriority(0)
            if let quota = presentation.quotaSummary {
                Text("-")
                    .foregroundStyle(presentation.secondaryTextTint.color)
                Text(quota)
                    .foregroundStyle(presentation.quotaTextTint.color)
                    .truncationMode(.tail)
                    .layoutPriority(1)
            }
        }
        .font(.caption)
        .lineLimit(1)
    }
}
