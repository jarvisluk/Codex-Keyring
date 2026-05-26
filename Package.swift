// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CodexKeyring",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "CodexKeyring",
            targets: ["CodexKeyring"]
        )
    ],
    targets: [
        .executableTarget(
            name: "CodexKeyring"
        )
    ]
)
