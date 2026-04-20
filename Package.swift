// swift-tools-version: 6.2
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
        .library(
            name: "SerpApi",
            targets: ["SerpApi"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-docc-plugin", from: "1.0.0"),
    ],
    targets: [
        .target(
            name: "SerpApi"
        ),
        .testTarget(
            name: "SerpApiTests",
            dependencies: ["SerpApi"]
        ),
    ]
)
