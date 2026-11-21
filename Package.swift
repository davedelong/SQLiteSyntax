// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

// The types in Sources/SQLiteSyntax/Generated (and their parsers, in Generated/Parsing) are produced
// by the generator in the sibling SQLiteSyntaxGenerator package; see README.md.
let package = Package(
    name: "SQLiteSyntax",
    platforms: [.macOS(.v11), .iOS(.v13), .watchOS(.v7), .tvOS(.v13), .visionOS(.v1)],
    products: [
        .library(
            name: "SQLiteSyntax",
            targets: ["SQLiteSyntax"]),
    ],
    targets: [
        .target(
            name: "SQLiteSyntax"),
        .testTarget(
            name: "SQLiteSyntaxTests",
            dependencies: ["SQLiteSyntax"]
        ),
        .testTarget(
            name: "ParsingTests",
            dependencies: ["SQLiteSyntax"]
        ),
    ]
)
