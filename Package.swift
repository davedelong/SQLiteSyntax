// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SQLiteSyntax",
    platforms: [.macOS(.v11), .iOS(.v13), .watchOS(.v7), .tvOS(.v13), .visionOS(.v1)],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "SQLiteSyntax",
            targets: ["SQLiteSyntax"]),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "SQLiteSyntax"),
        .testTarget(
            name: "SQLiteSyntaxTests",
            dependencies: ["SQLiteSyntax"]
        ),

        // MARK: Grammar extraction (development tooling; not part of the library product)

        // The Pikchr diagram renderer, vendored unmodified from sqlite-docsrc/search/pikchr.c.
        .target(
            name: "CPikchr"
        ),
        // Reads SQLite's railroad syntax diagrams and turns them into a verified EBNF grammar.
        .target(
            name: "GrammarExtraction",
            dependencies: ["CPikchr"]
        ),
        .executableTarget(
            name: "sqlite-grammar",
            dependencies: ["GrammarExtraction"]
        ),
        .plugin(
            name: "GenerateGrammar",
            capability: .command(
                intent: .custom(
                    verb: "generate-grammar",
                    description: "Regenerate Grammar/sqlite.ebnf from the SQLite documentation's syntax diagrams"
                ),
                permissions: [
                    .writeToPackageDirectory(reason: "Writes the extracted grammar to Grammar/sqlite.ebnf")
                ]
            )
        ),
        .testTarget(
            name: "GrammarExtractionTests",
            dependencies: ["GrammarExtraction"],
            resources: [.copy("Fixtures")]
        ),
    ]
)
