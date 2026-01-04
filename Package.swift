// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SerpApi",
    platforms: [
        .macOS(.v12),
        .iOS(.v15),
        .tvOS(.v15),
        .watchOS(.v8)
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "SerpApi",
            targets: ["SerpApi"]
        ),
        .executable(
            name: "Demo",
            targets: ["Demo"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-docc-plugin", from: "1.0.0"),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "SerpApi"
        ),
        .executableTarget(
            name: "Demo",
            dependencies: ["SerpApi"]
        ),
        .testTarget(
            name: "SerpApiTests",
            dependencies: ["SerpApi"]
        ),
    ]
)
