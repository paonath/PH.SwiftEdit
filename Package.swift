// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "PH.SwiftEdit",
    platforms: [
        .macOS(.v26),
        .iOS(.v26),
    ],
    products: [
        .library(
            name: "SwiftEditCore",
            targets: ["SwiftEditCore"]
        ),
        .library(
            name: "SwiftEditUI",
            targets: ["SwiftEditUI"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-markdown.git", from: "0.5.0"),
    ],
    targets: [
        .target(
            name: "SwiftEditCore",
            dependencies: [
                .product(name: "Markdown", package: "swift-markdown"),
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .unsafeFlags(["-Xfrontend", "-strict-concurrency=complete"], .when(configuration: .debug)),
            ]
        ),
        .target(
            name: "SwiftEditUI",
            dependencies: [
                "SwiftEditCore",
            ],
            resources: [
                // OpenDyslexic (SIL OFL 1.1, unmodified upstream files, SHA-256 pinned in OpenDyslexicBundle).
                .copy("Resources/Fonts"),
                // In-app Help: a copy of the repository README (kept identical by HelpDocumentationTests).
                .copy("Resources/Help"),
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .unsafeFlags(["-Xfrontend", "-strict-concurrency=complete"], .when(configuration: .debug)),
            ]
        ),
        .testTarget(
            name: "SwiftEditTests",
            dependencies: [
                "SwiftEditCore",
                "SwiftEditUI",
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6),
            ]
        ),
    ]
)
