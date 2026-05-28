import SwiftUI
import CodexKeyringDomain

struct AccountQuotaSnapshotView: View {
    let snapshot: AccountQuotaSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: KeyringStyle.Spacing.contentGroup) {
            if let primary = snapshot.primaryBucket {
                AccountQuotaBucketView(bucket: primary, prominent: true)
            }

            if !additionalBuckets.isEmpty {
                Divider()
                ForEach(additionalBuckets) { bucket in
                    AccountQuotaBucketView(bucket: bucket, prominent: false)
                }
            }

            Text("Last checked \(snapshot.fetchedAt.formatted(date: .abbreviated, time: .shortened))")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var additionalBuckets: [QuotaBucket] {
        snapshot.buckets.filter { $0.id != snapshot.primaryBucket?.id }
    }
}
