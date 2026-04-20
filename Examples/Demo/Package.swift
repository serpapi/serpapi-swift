// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Demo",
    platforms: [
        .macOS(.v12)
    ],
    dependencies: [
        .package(path: "../../")
    ],
    targets: [
        .executableTarget(
            name: "Demo",
            dependencies: [
                .product(name: "SerpApi", package: "serpapi-swift")
            ],
            path: "Sources"
        ),
        .testTarget(
            name: "DemoTests",
            dependencies: ["Demo"],
            path: "Tests"
        ),
    ]
)
