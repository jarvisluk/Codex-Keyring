import SwiftUI
import CodexKeyringDomain

struct AccountQuotaCreditsView: View {
    let credits: QuotaCredits

    private var presentation: QuotaCreditsPresentation {
        QuotaCreditsPresentation(credits: credits)
    }

    var body: some View {
        if presentation.isVisible {
            Label(
                presentation.label,
                systemImage: presentation.systemImage
            )
            .font(.caption)
            .foregroundStyle(presentation.tint.color)
        }
    }
}
