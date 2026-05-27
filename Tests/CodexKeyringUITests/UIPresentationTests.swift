import XCTest
@testable import CodexKeyringDomain
@testable import CodexKeyringUI

final class UIPresentationTests: XCTestCase {
    @MainActor
    func testSettingsPresentationStoreTogglesModalState() {
        let store = SettingsPresentationStore()

        XCTAssertFalse(store.isPresented)

        store.present()
        XCTAssertTrue(store.isPresented)

        store.dismiss()
        XCTAssertFalse(store.isPresented)
    }

    func testMenuBarAccountPresentationCapsLongDisplayName() {
        let account = makeAccount(alias: "abcdefghijklmnopqrstuvwxyz1234567890")

        let presentation = MenuBarAccountPresentation(account: account)

        XCTAssertEqual(presentation.title, "abcdefghijklmnopqrstuvwxyz1...")
    }

    func testCurrentAuthFooterPresentationUsesSavedAccountName() {
        let account = makeAccount(alias: "Work")
        let metadata = makeMetadata(email: "  person@example.com  ")

        let presentation = CurrentAuthFooterPresentation(
            metadata: metadata,
            savedAccount: account,
            authPath: "/Users/example/.codex/auth.json"
        )

        XCTAssertEqual(presentation.title, "person@example.com")
        XCTAssertEqual(presentation.subtitle, "Saved as Work")
        XCTAssertEqual(presentation.contextMenuTitle, "Already in Credentials")
        XCTAssertEqual(
            presentation.accessibilitySummary,
            "Current Codex Auth: person@example.com. Saved as Work."
        )
    }

    func testAddCurrentAccountSummaryUsesFallbacksForBlankMetadata() {
        let summary = AddCurrentAccountSummary(metadata: makeMetadata(
            email: " ",
            plan: "\n",
            authMode: "\t",
            fingerprint: ""
        ))

        XCTAssertEqual(summary.email, "Unknown email")
        XCTAssertEqual(summary.plan, "Unknown")
        XCTAssertEqual(summary.authMode, "Unknown")
        XCTAssertEqual(summary.fingerprint, "Unknown")
    }

    func testAccountDetailMetadataPresentationTrimsVisibleMetadata() {
        let account = makeAccount(
            plan: "  Plus  ",
            authMode: "  chatgpt  ",
            accountIdentifier: "  acct-123  ",
            fingerprint: "abcdef1234567890"
        )

        let presentation = AccountDetailMetadataPresentation(account: account)

        XCTAssertEqual(presentation.authMode, "chatgpt")
        XCTAssertEqual(presentation.plan, "Plus")
        XCTAssertEqual(presentation.accountIdentifier, "acct-123")
        XCTAssertEqual(presentation.fingerprint, "abcdef1234")
    }

    func testQuotaMenuDetailSummaryPrefersTwoCompactWindows() throws {
        let accountID = UUID()
        let snapshot = AccountQuotaSnapshot(
            accountID: accountID,
            planType: "plus",
            email: "person@example.com",
            fetchedAt: Date(timeIntervalSince1970: 0),
            buckets: [
                QuotaBucket(
                    limitID: "codex",
                    limitName: "Codex",
                    planType: "plus",
                    windows: [
                        QuotaWindow(usedPercent: 80, windowDurationMinutes: 24 * 60, resetsAt: nil),
                        QuotaWindow(usedPercent: 1, windowDurationMinutes: 5 * 60, resetsAt: nil),
                        QuotaWindow(usedPercent: 2, windowDurationMinutes: 7 * 24 * 60, resetsAt: nil)
                    ],
                    credits: nil,
                    rateLimitReachedType: nil
                )
            ],
            endpoint: nil
        )

        let summary = try XCTUnwrap(AccountQuotaState.available(snapshot).menuDetailSummary)

        XCTAssertEqual(summary, "5h 99% left · week 98% left")
    }

    private func makeAccount(
        alias: String = "Personal",
        email: String = "person@example.com",
        plan: String = "Plus",
        authMode: String = "chatgpt",
        accountIdentifier: String = "acct",
        fingerprint: String = "fingerprint"
    ) -> CodexAccount {
        CodexAccount(
            id: UUID(),
            alias: alias,
            email: email,
            plan: plan,
            authMode: authMode,
            accountIdentifier: accountIdentifier,
            snapshotFileName: "snapshot.json",
            fingerprint: fingerprint,
            createdAt: Date(timeIntervalSince1970: 0),
            updatedAt: Date(timeIntervalSince1970: 0),
            tokenExpiresAt: nil
        )
    }

    private func makeMetadata(
        email: String,
        plan: String = "Plus",
        authMode: String = "chatgpt",
        fingerprint: String = "fingerprint"
    ) -> AuthMetadata {
        AuthMetadata(
            email: email,
            plan: plan,
            authMode: authMode,
            accountIdentifier: "acct",
            fingerprint: fingerprint,
            tokenExpiresAt: nil
        )
    }
}
