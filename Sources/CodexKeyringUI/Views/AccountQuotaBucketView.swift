import SwiftUI
import CodexKeyringDomain

struct AccountQuotaBucketView: View {
    let bucket: QuotaBucket
    let prominent: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: KeyringStyle.Spacing.compact) {
            header

            if let planType = bucket.planType, !planType.isEmpty {
                Text("Plan: \(planType)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ForEach(Array(bucket.windows.enumerated()), id: \.offset) { _, window in
                AccountQuotaWindowView(window: window)
            }

            if bucket.isUnlimited {
                Label("Quota: unlimited", systemImage: "infinity")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let credits = bucket.credits {
                AccountQuotaCreditsView(credits: credits)
            }
        }
    }

    private var header: some View {
        HStack {
            Label(bucket.displayName, systemImage: bucket.health.systemImage)
                .foregroundStyle(bucket.health.tint)
                .font(prominent ? .headline : .subheadline.weight(.semibold))
                .lineLimit(2)
                .truncationMode(.middle)

            Spacer()

            Text(bucket.health.label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(bucket.health.tint)
        }
    }
}
