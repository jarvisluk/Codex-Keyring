import XCTest
@testable import CodexKeyringUI

final class CurrentAuthPresentationTests: XCTestCase {
    func testCurrentAuthFooterPresentationUsesSavedAccountName() {
        let account = makePresentationAccount(alias: "Work")
        let metadata = makePresentationMetadata(email: "  person@example.com  ")

        let presentation = CurrentAuthFooterPresentation(
            metadata: metadata,
            savedAccount: account,
            authPath: "/Users/example/.codex/auth.json"
        )

        XCTAssertEqual(presentation.title, "person@example.com")
        XCTAssertEqual(presentation.subtitle, "Saved as Work")
        XCTAssertEqual(presentation.contextMenuTitle, "Already in Credentials")
        XCTAssertEqual(presentation.statusSystemImage, "checkmark.circle.fill")
        XCTAssertEqual(presentation.statusIconTint, .saved)
        XCTAssertEqual(
            presentation.accessibilitySummary,
            "Current Codex Auth: person@example.com. Saved as Work."
        )
    }

    func testCurrentAuthFooterPresentationDistinguishesUnsavedAndUnreadableAuth() {
        let unsaved = CurrentAuthFooterPresentation(
            metadata: makePresentationMetadata(email: "person@example.com"),
            savedAccount: nil,
            authPath: "/Users/example/.codex/auth.json"
        )
        let unreadable = CurrentAuthFooterPresentation(
            metadata: nil,
            savedAccount: nil,
            authPath: "/Users/example/.codex/auth.json"
        )

        XCTAssertEqual(unsaved.statusSystemImage, "circle")
        XCTAssertEqual(unsaved.statusIconTint, .secondary)
        XCTAssertEqual(unreadable.statusSystemImage, "person.crop.circle.badge.questionmark")
        XCTAssertEqual(unreadable.statusIconTint, .secondary)
        XCTAssertEqual(unreadable.title, "No readable auth.json")
    }

    func testCurrentAuthFooterPresentationCarriesSaveActionState() {
        let visible = CurrentAuthFooterPresentation(
            metadata: makePresentationMetadata(email: "person@example.com"),
            savedAccount: nil,
            authPath: "/Users/example/.codex/auth.json",
            showsSaveAction: true,
            canSaveAction: false
        )
        let hidden = CurrentAuthFooterPresentation(
            metadata: nil,
            savedAccount: nil,
            authPath: "/Users/example/.codex/auth.json",
            showsSaveAction: false,
            canSaveAction: false
        )

        XCTAssertTrue(visible.showsSaveAction)
        XCTAssertFalse(visible.canSaveAction)
        XCTAssertFalse(hidden.showsSaveAction)
        XCTAssertFalse(hidden.canSaveAction)
    }

    func testAddCurrentAccountSummaryUsesFallbacksForBlankMetadata() {
        let summary = AddCurrentAccountSummary(metadata: makePresentationMetadata(
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

    func testAddCurrentAccountSheetPresentationCarriesSummaryAndSaveState() {
        let metadata = makePresentationMetadata(email: "person@example.com", plan: "plus")

        let readable = AddCurrentAccountSheetPresentation(metadata: metadata, canSave: true)
        let unreadable = AddCurrentAccountSheetPresentation(metadata: nil, canSave: false)

        XCTAssertEqual(readable.summary, AddCurrentAccountSummary(metadata: metadata))
        XCTAssertTrue(readable.canSave)
        XCTAssertNil(unreadable.summary)
        XCTAssertFalse(unreadable.canSave)
        XCTAssertEqual(unreadable.unreadableAuthTitle, "No readable Codex auth.json")
        XCTAssertEqual(unreadable.unreadableAuthSystemImage, "exclamationmark.triangle")
    }

}
