// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "EventsDemo",
    platforms: [
        .macOS(.v12),
        .iOS(.v15)
    ],
    dependencies: [
        .package(path: "../../")
    ],
    targets: [
        .executableTarget(
            name: "EventsDemo",
            dependencies: [
                .product(name: "SerpApi", package: "serpapi-swift")
            ],
            path: "Sources",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "EventsDemoTests",
            dependencies: ["EventsDemo"],
            path: "Tests"
        ),
    ]
)
