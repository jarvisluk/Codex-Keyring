import Foundation
import CodexKeyringDomain

struct AddCurrentAccountSheetPresentation: Equatable {
    let summary: AddCurrentAccountSummary?
    let canSave: Bool
    let unreadableAuthTitle: String
    let unreadableAuthSystemImage: String

    init(metadata: AuthMetadata?, canSave: Bool) {
        summary = metadata.map(AddCurrentAccountSummary.init)
        self.canSave = canSave
        unreadableAuthTitle = "No readable Codex auth.json"
        unreadableAuthSystemImage = "exclamationmark.triangle"
    }
}

struct AddCurrentAccountSummary: Equatable {
    let email: String
    let plan: String
    let authMode: String
    let fingerprint: String

    init(metadata: AuthMetadata) {
        email = MetadataDisplayText.text(metadata.email, fallback: "Unknown email")
        plan = MetadataDisplayText.text(metadata.plan, fallback: "Unknown")
        authMode = MetadataDisplayText.text(metadata.authMode, fallback: "Unknown")
        fingerprint = MetadataDisplayText.fingerprint(metadata.fingerprint)
    }
}
