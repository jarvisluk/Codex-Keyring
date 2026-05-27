import XCTest
@testable import CodexKeyringInfrastructure

final class AppPathsTests: XCTestCase {
    func testApplicationSupportDirectoryUsesFirstFinderCandidate() {
        let firstCandidate = URL(fileURLWithPath: "/tmp/Library/Application Support", isDirectory: true)
        let secondCandidate = URL(fileURLWithPath: "/tmp/Other Support", isDirectory: true)
        let homeDirectory = URL(fileURLWithPath: "/tmp/home", isDirectory: true)

        let directory = AppPaths.applicationSupportDirectory(
            candidates: [firstCandidate, secondCandidate],
            homeDirectory: homeDirectory
        )

        XCTAssertEqual(
            directory,
            firstCandidate.appendingPathComponent(AppPaths.appName, isDirectory: true)
        )
    }

    func testApplicationSupportDirectoryFallsBackToHomeLibraryWhenFinderReturnsNoCandidates() {
        let homeDirectory = URL(fileURLWithPath: "/tmp/home", isDirectory: true)

        let directory = AppPaths.applicationSupportDirectory(
            candidates: [],
            homeDirectory: homeDirectory
        )

        XCTAssertEqual(
            directory,
            homeDirectory
                .appendingPathComponent("Library", isDirectory: true)
                .appendingPathComponent("Application Support", isDirectory: true)
                .appendingPathComponent(AppPaths.appName, isDirectory: true)
        )
    }
}
