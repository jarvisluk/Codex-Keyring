import Foundation
import CodexKeyringDomain

struct AccountDetailMetadataPresentation: Equatable {
    let authMode: String
    let plan: String
    let accountIdentifier: String
    let fingerprint: String

    init(account: CodexAccount) {
        authMode = MetadataDisplayText.text(account.authMode, fallback: "Unknown")
        plan = MetadataDisplayText.text(account.plan, fallback: "Unknown")
        accountIdentifier = MetadataDisplayText.text(account.accountIdentifier, fallback: "Unknown")
        fingerprint = MetadataDisplayText.fingerprint(account.fingerprint)
    }
}
