// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "TuckNote",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "TuckNote", targets: ["TuckNote"])],
    dependencies: [
        .package(url: "https://github.com/nodes-app/swift-markdown-engine", from: "0.1.0"),
        .package(url: "https://github.com/sindresorhus/KeyboardShortcuts", from: "2.4.0")
    ],
    targets: [
        .executableTarget(
            name: "TuckNote",
            dependencies: [
                .product(name: "MarkdownEngine", package: "swift-markdown-engine"),
                .product(name: "MarkdownEngineCodeBlocks", package: "swift-markdown-engine"),
                .product(name: "KeyboardShortcuts", package: "KeyboardShortcuts")
            ]
        ),
        .testTarget(name: "TuckNoteTests", dependencies: ["TuckNote"])
    ]
)
