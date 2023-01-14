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
        .package(url: "https://github.com/pointfreeco/swift-custom-dump", from: "0.6.0"),
        .package(url: "https://github.com/yonaskolb/SwiftGUI", from: "0.2.2"),
        .package(url: "https://github.com/pointfreeco/swift-dependencies", from: "0.1.2"),
        .package(url: "https://github.com/pointfreeco/swiftui-navigation", from: "0.4.5"),
        .package(url: "https://github.com/pointfreeco/swift-case-paths", from: "0.10.0"),
        .package(url: "https://github.com/pointfreeco/swift-parsing", from: "0.10.0"),
        .package(url: "https://github.com/Sherlouk/AccessibilitySnapshot", branch: "update-snapshot-testing"),
        .package(url: "https://github.com/wickwirew/Runtime", from: "2.2.4"),
        .package(url: "https://github.com/nicklockwood/SwiftFormat", branch: "develop"),
    ],
    targets: [
        .target(
            name: "SwiftComponent",
            dependencies: [
                .product(name: "CustomDump", package: "swift-custom-dump"),
                .product(name: "CasePaths", package: "swift-case-paths"),
                .product(name: "Parsing", package: "swift-parsing"),
                .product(name: "Dependencies", package: "swift-dependencies"),
                .product(name: "SwiftUINavigation", package: "swiftui-navigation"),
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
