import Foundation
import XCTest
@testable import CodexKeyringInfrastructure

struct OAuthLoginServiceFixture {
    let tempDirectory: URL
    let codexDirectory: URL
    let authFileURL: URL
    let service: ChatGPTOAuthLoginService
}

class ChatGPTOAuthLoginServiceTestCase: XCTestCase {
    private var tempDirectories: [URL] = []

    override func tearDown() {
        OAuthLoginURLProtocol.reset()
        for tempDirectory in tempDirectories {
            try? FileManager.default.removeItem(at: tempDirectory)
        }
        tempDirectories = []
        super.tearDown()
    }

    func makeOAuthTempDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ChatGPTOAuthLoginServiceTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        tempDirectories.append(directory)
        return directory
    }

    func makeOAuthLoginServiceFixture(
        ioQueue: DispatchQueue = DispatchQueue(label: "tests.ChatGPTOAuthLoginService.io")
    ) throws -> OAuthLoginServiceFixture {
        let tempDirectory = try makeOAuthTempDirectory()
        let codexDirectory = tempDirectory.appendingPathComponent("codex", isDirectory: true)
        let authFileURL = codexDirectory.appendingPathComponent("auth.json")
        return OAuthLoginServiceFixture(
            tempDirectory: tempDirectory,
            codexDirectory: codexDirectory,
            authFileURL: authFileURL,
            service: try makeOAuthLoginService(
                authFileURL: authFileURL,
                codexDirectory: codexDirectory,
                ioQueue: ioQueue
            )
        )
    }

    func makeOAuthLoginService(
        issuer: String = "https://auth.test",
        authFileURL: URL,
        codexDirectory: URL,
        urlSession: URLSession = OAuthLoginURLProtocol.session,
        ioQueue: DispatchQueue = DispatchQueue(label: "tests.ChatGPTOAuthLoginService.io")
    ) throws -> ChatGPTOAuthLoginService {
        ChatGPTOAuthLoginService(
            issuer: try oauthTestURL(issuer),
            authFileURL: authFileURL,
            codexDirectory: codexDirectory,
            urlSession: urlSession,
            ioQueue: ioQueue
        )
    }
}
