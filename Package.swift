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
        .package(url: "https://github.com/pointfreeco/swift-custom-dump", from: "0.7.0"),
        .package(url: "https://github.com/yonaskolb/SwiftGUI", from: "0.2.2"),
        .package(url: "https://github.com/pointfreeco/swift-dependencies", from: "0.1.4"),
        .package(url: "https://github.com/pointfreeco/swift-parsing", from: "0.10.0"),
        .package(url: "https://github.com/cashapp/AccessibilitySnapshot", from: "0.6.0"),
        .package(url: "https://github.com/wickwirew/Runtime", from: "2.2.4"),
    ],
    targets: [
        .target(
            name: "SwiftComponent",
            dependencies: [
                .product(name: "CustomDump", package: "swift-custom-dump"),
                .product(name: "Parsing", package: "swift-parsing"),
                .product(name: "Dependencies", package: "swift-dependencies"),
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
