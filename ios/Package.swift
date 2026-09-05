// swift-tools-version: 6.0
import CompilerPluginSupport
import PackageDescription

let package = Package(
    name: "PororocaOTA",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "Pororoca", targets: ["Pororoca"]),
        .library(name: "PororocaDocument", targets: ["PororocaDocument"]),
        .library(name: "PororocaExpr", targets: ["PororocaExpr"]),
        .library(name: "PororocaDSL", targets: ["PororocaDSL"]),
        .library(name: "PororocaRuntime", targets: ["PororocaRuntime"]),
        .library(name: "PororocaUpdate", targets: ["PororocaUpdate"]),
        .executable(name: "pororoca", targets: ["PororocaPublisher"]),
        .executable(name: "pororoca-lift-report", targets: ["pororoca-lift-report"]),
    ],
    dependencies: [
        // Pinned to the swift-syntax release that matches the installed toolchain (Swift 6.3.2 → 603.x).
        .package(url: "https://github.com/swiftlang/swift-syntax.git", exact: "603.0.2"),
        .package(url: "https://github.com/pointfreeco/swift-snapshot-testing.git", from: "1.19.4"),
    ],
    targets: [
        // Libraries
        .target(name: "PororocaExpr"),
        .target(name: "PororocaDocument", dependencies: ["PororocaExpr"]),
        .target(name: "PororocaDSL", dependencies: ["PororocaDocument"]),
        .target(name: "PororocaRuntime", dependencies: ["PororocaDocument", "PororocaExpr"]),
        .target(name: "PororocaUpdate", dependencies: ["PororocaDocument"]),
        .target(
            name: "PororocaLiftAnalysis",
            dependencies: [
                .product(name: "SwiftParser", package: "swift-syntax"),
                .product(name: "SwiftSyntax", package: "swift-syntax"),
            ],
            path: "Sources/PororocaMacros/Lifter",
            exclude: ["Diagnostics.swift", "ExprLifter.swift", "ModifierLifter.swift", "ViewLifter.swift", "Whitelist.swift"],
            sources: ["CoverageClassifier.swift"]
        ),
        .macro(
            name: "PororocaMacros",
            dependencies: [
                "PororocaDSL",
                .product(name: "SwiftDiagnostics", package: "swift-syntax"),
                .product(name: "SwiftParser", package: "swift-syntax"),
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftSyntaxBuilder", package: "swift-syntax"),
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
            ],
            exclude: ["Lifter/CoverageClassifier.swift"]
        ),
        .target(
            name: "Pororoca",
            dependencies: ["PororocaDocument", "PororocaExpr", "PororocaDSL", "PororocaRuntime", "PororocaUpdate", "PororocaMacros"]
        ),

        // Executables
        .executableTarget(name: "PororocaPublisher", dependencies: ["PororocaDocument", "PororocaUpdate"]),
        .executableTarget(name: "pororoca-lift-report", dependencies: ["PororocaLiftAnalysis"]),

        // Tests
        .testTarget(name: "PororocaExprTests", dependencies: ["PororocaExpr"]),
        .testTarget(name: "PororocaDocumentTests", dependencies: ["PororocaDocument", "PororocaExpr"]),
        .testTarget(name: "PororocaDSLTests", dependencies: ["PororocaDSL"]),
        .testTarget(
            name: "PororocaRuntimeTests",
            dependencies: [
                "PororocaRuntime",
                "PororocaDocument",
                "PororocaExpr",
                .product(name: "SnapshotTesting", package: "swift-snapshot-testing"),
            ],
            exclude: ["__Snapshots__"]
        ),
        .testTarget(name: "PororocaUpdateTests", dependencies: ["PororocaUpdate"]),
        .testTarget(
            name: "PororocaMacrosTests",
            dependencies: [
                "PororocaMacros",
                "PororocaLiftAnalysis",
                .product(name: "SwiftParser", package: "swift-syntax"),
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftSyntaxMacrosTestSupport", package: "swift-syntax"),
            ]
        ),
        .testTarget(name: "PororocaTests", dependencies: ["Pororoca"]),
    ],
    swiftLanguageModes: [.v6]
)
