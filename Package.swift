// swift-tools-version: 5.6
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SwiftComponent",
    platforms: [.iOS(.v15), .macOS(.v12)],
    products: [
        .library(name: "SwiftComponent", targets: ["SwiftComponent"]),
    ],
    dependencies: [
        .package(url: "https://github.com/yonaskolb/SwiftGUI", from: "0.2.2"),
        .package(url: "https://github.com/pointfreeco/swift-custom-dump", from: "1.0.0"),
        .package(url: "https://github.com/yonaskolb/swift-dependencies", branch: "merging"),
        .package(url: "https://github.com/pointfreeco/swift-case-paths", from: "1.0.0"),
        .package(url: "https://github.com/cashapp/AccessibilitySnapshot", from: "0.6.0"),
        .package(url: "https://github.com/wickwirew/Runtime", from: "2.2.4"),
        .package(url: "https://github.com/apple/swift-syntax", branch: "main")
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
            ]),
        .target(
            name: "SwiftPreview",
            dependencies: [
                .product(name: "AccessibilitySnapshotCore", package: "AccessibilitySnapshot"),
            ]),
        .testTarget(
            name: "SwiftComponentTests",
            dependencies: ["SwiftComponent"]),
    ]
)
