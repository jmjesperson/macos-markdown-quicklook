// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MarkdownRenderer",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "MarkdownRenderer", targets: ["MarkdownRenderer"]),
    ],
    dependencies: [
        // GitHub's cmark-gfm, as maintained by the Swift project. Pinned exactly; see docs/third-party.md.
        .package(url: "https://github.com/swiftlang/swift-cmark.git", exact: "0.9.0"),
    ],
    targets: [
        .target(
            name: "MarkdownRenderer",
            dependencies: [
                .product(name: "cmark-gfm", package: "swift-cmark"),
                .product(name: "cmark-gfm-extensions", package: "swift-cmark"),
            ],
            resources: [.copy("Resources")]
        ),
        // Developer tool for inspecting and timing output; not linked into the app.
        .executableTarget(name: "markdown-render", dependencies: ["MarkdownRenderer"]),
        .testTarget(
            name: "MarkdownRendererTests",
            dependencies: ["MarkdownRenderer"],
            exclude: ["Fixtures", "Snapshots"]
        ),
    ]
)
