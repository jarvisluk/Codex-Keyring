import XCTest
@testable import CodexKeyringDomain
@testable import CodexKeyringUI

final class SidebarAccountPresentationTests: XCTestCase {
    func testSidebarAccountPresentationCombinesIdentityStatusAndQuota() {
        let account = makePresentationAccount(alias: "Work", email: "  person@example.com  ")
        let quota = makeAvailableQuotaState(
            accountID: account.id,
            limitName: "Codex",
            windows: [
                makeQuotaWindow(usedPercent: 25)
            ]
        )

        let presentation = SidebarAccountPresentation(
            account: account,
            isActive: true,
            quotaState: quota
        )

        XCTAssertEqual(presentation.title, "Work")
        XCTAssertEqual(presentation.detailSummary, "Plus - 5h 75%")
        XCTAssertEqual(presentation.detailAccessibilitySummary, "Plus - 5h 75% left")
        XCTAssertEqual(presentation.statusSystemImage, "checkmark.circle.fill")
        XCTAssertEqual(presentation.statusIconTint, .active)
        XCTAssertEqual(presentation.titleTint, .primary)
        XCTAssertEqual(presentation.quotaTextTint, .quotaHealth(.ready))
        XCTAssertEqual(presentation.accessibilitySummary, "Work, active, Plus - 5h 75% left")
    }

    func testSidebarAccountPresentationDoesNotExposeEmailFallback() {
        let account = makePresentationAccount(alias: "", email: "person@example.com", plan: "Business")

        let presentation = SidebarAccountPresentation(
            account: account,
            isActive: true,
            quotaState: nil
        )

        XCTAssertEqual(presentation.title, "Unnamed account")
        XCTAssertEqual(presentation.detailSummary, "Business")
        XCTAssertEqual(presentation.accessibilitySummary, "Unnamed account, active, Business")
    }

    func testSidebarAccountPresentationCarriesSelectedTints() {
        let account = makePresentationAccount(alias: "Work")

        let presentation = SidebarAccountPresentation(
            account: account,
            isActive: false,
            isSelected: true,
            quotaState: nil
        )

        XCTAssertEqual(presentation.statusIconTint, .selectedSecondary)
        XCTAssertEqual(presentation.titleTint, .selectedPrimary)
        XCTAssertEqual(presentation.quotaTextTint, .selectedPrimary)
    }
}
