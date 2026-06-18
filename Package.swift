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
            targets: ["CodexKeyringApp"]
        ),
        .executable(
            name: "ckr",
            targets: ["CodexKeyringCLIExecutable"]
        ),
        .executable(
            name: "codex-keyring",
            targets: ["CodexKeyringCLIExecutable"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.9.0")
    ],
    targets: [
        .executableTarget(
            name: "CodexKeyringApp",
            dependencies: [
                "CodexKeyringUI",
                "CodexKeyringInfrastructure"
            ]
        ),
        .executableTarget(
            name: "CodexKeyringCLIExecutable",
            dependencies: [
                "CodexKeyringCLI"
            ]
        ),
        .target(
            name: "CodexKeyringCLI",
            dependencies: [
                "CodexKeyringDomain",
                "CodexKeyringInfrastructure"
            ]
        ),
        .target(
            name: "CodexKeyringUI",
            dependencies: [
                "CodexKeyringDomain",
                .product(name: "Sparkle", package: "Sparkle")
            ]
        ),
        .target(
            name: "CodexKeyringInfrastructure",
            dependencies: [
                "CodexKeyringDomain"
            ]
        ),
        .target(
            name: "CodexKeyringDomain"
        ),
        .testTarget(
            name: "CodexKeyringDomainTests",
            dependencies: ["CodexKeyringDomain"]
        ),
        .testTarget(
            name: "CodexKeyringInfrastructureTests",
            dependencies: ["CodexKeyringInfrastructure"]
        ),
        .testTarget(
            name: "CodexKeyringCLITests",
            dependencies: ["CodexKeyringCLI"]
        ),
        .testTarget(
            name: "CodexKeyringUITests",
            dependencies: ["CodexKeyringUI"]
        )
    ]
)
