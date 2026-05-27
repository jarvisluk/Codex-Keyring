import XCTest
@testable import CodexKeyringInfrastructure

final class LiveAuthFileWatcherTests: XCTestCase {
    private let tempDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("LiveAuthFileWatcherTests-\(UUID().uuidString)", isDirectory: true)
    private lazy var authURL = tempDirectory.appendingPathComponent("auth.json")

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDirectory)
    }

    func testStartsWatchingWhenAuthFileAppearsAfterLaunch() async throws {
        let watcher = makeWatcher()
        let signal = OneShot()
        let changed = expectation(description: "watcher noticed auth file after reattach")

        watcher.start {
            if signal.fire() {
                changed.fulfill()
            }
        }
        defer { watcher.stop() }

        try FileManager.default.createDirectory(
            at: tempDirectory,
            withIntermediateDirectories: true
        )
        try Data("first".utf8).write(to: authURL)

        await fulfillment(of: [changed], timeout: 2)
    }

    func testReattachesAfterAtomicReplacement() async throws {
        try FileManager.default.createDirectory(
            at: tempDirectory,
            withIntermediateDirectories: true
        )
        try Data("first".utf8).write(to: authURL)

        let watcher = makeWatcher()
        let initialSignal = OneShot()
        let initialChange = expectation(description: "initial watch attach")
        watcher.start {
            if initialSignal.fire() {
                initialChange.fulfill()
            }
        }
        defer { watcher.stop() }
        await fulfillment(of: [initialChange], timeout: 2)

        let replacementSignal = OneShot()
        let replacementChange = expectation(description: "watcher noticed atomic replacement")
        watcher.start {
            if replacementSignal.fire() {
                replacementChange.fulfill()
            }
        }

        let replacement = tempDirectory.appendingPathComponent("replacement-auth.json")
        try Data("second".utf8).write(to: replacement)
        _ = try FileManager.default.replaceItemAt(authURL, withItemAt: replacement)

        await fulfillment(of: [replacementChange], timeout: 2)
        XCTAssertEqual(try String(contentsOf: authURL, encoding: .utf8), "second")
    }

    private func makeWatcher() -> LiveAuthFileWatcher {
        LiveAuthFileWatcher(
            url: authURL,
            queue: DispatchQueue(label: "tests.LiveAuthFileWatcher.\(UUID().uuidString)"),
            debounceInterval: .milliseconds(10),
            reattachInterval: .milliseconds(20)
        )
    }
}

private final class OneShot: @unchecked Sendable {
    private let lock = NSLock()
    private var didFire = false

    func fire() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard !didFire else { return false }
        didFire = true
        return true
    }
}
