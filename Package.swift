// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription
import CompilerPluginSupport

var package = Package(
    name: "SwiftComponent",
    platforms: [.iOS(.v15), .macOS(.v12)],
    products: [
        .library(name: "SwiftComponent", targets: ["SwiftComponent"]),
    ],
    dependencies: [
        .package(url: "https://github.com/yonaskolb/SwiftGUI", from: "0.2.2"),
        .package(url: "https://github.com/pointfreeco/swift-custom-dump", from: "1.3.0"),
        .package(url: "https://github.com/yonaskolb/swift-dependencies", branch: "merging"),
        .package(url: "https://github.com/pointfreeco/swift-case-paths", from: "1.1.0"),
        .package(url: "https://github.com/pointfreeco/swift-macro-testing", from: "0.2.1"),
        .package(url: "https://github.com/wickwirew/Runtime", from: "2.2.6"),
        .package(url: "https://github.com/apple/swift-syntax", from: "509.0.0"),
        .package(url: "https://github.com/cashapp/AccessibilitySnapshot", branch: "master"),
    ],
    targets: [
        .target(
            name: "SwiftComponent",
            dependencies: [
                .product(name: "CustomDump", package: "swift-custom-dump"),
                .product(name: "Dependencies", package: "swift-dependencies"),
                .product(name: "SwiftParser", package: "swift-syntax"),
                .product(name: "CasePaths", package: "swift-case-paths"),
                "SwiftGUI",
                "SwiftPreview",
                "Runtime",
                "SwiftComponentMacros",
            ]),
        .target(
            name: "SwiftPreview",
            dependencies: [
                .product(name: "AccessibilitySnapshotCore", package: "AccessibilitySnapshot", condition: .when(platforms: [.iOS])),
            ]),
        .testTarget(
            name: "SwiftComponentTests",
            dependencies: [
                "SwiftComponent",
                .product(name: "MacroTesting", package: "swift-macro-testing"),
            ]),
        .macro(
            name: "SwiftComponentMacros",
            dependencies: [
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax")
            ]
        ),
    ]
)
