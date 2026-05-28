import Foundation

struct ChatGPTOAuthFileWriter {
    let authFileURL: URL
    let codexDirectory: URL

    func write(tokens: ExchangedTokens) throws {
        let data = try ChatGPTOAuthJSONPayload(tokens: tokens).encodedData()
        try ChatGPTOAuthFileInstaller(
            authFileURL: authFileURL,
            codexDirectory: codexDirectory
        ).install(data: data)
    }
}
