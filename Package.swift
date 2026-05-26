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
        )
    ],
    targets: [
        .executableTarget(
            name: "CodexKeyringApp",
            dependencies: [
                "CodexKeyringUI",
                "CodexKeyringInfrastructure"
            ]
        ),
        .target(
            name: "CodexKeyringUI",
            dependencies: [
                "CodexKeyringDomain",
                "CodexKeyringInfrastructure"
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
        )
    ]
)
