import CodexKeyringCLI
import Darwin
import Foundation

@main
enum CodexKeyringCLIExecutable {
    static func main() async {
        let cli = CodexKeyringCLI()
        let code = await cli.run(arguments: Array(CommandLine.arguments.dropFirst()))
        exit(code)
    }
}
