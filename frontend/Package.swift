// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Aureum",
    platforms: [
        .macOS(.v14)
    ],
    dependencies: [
        .package(url: "https://github.com/hummingbird-project/hummingbird.git", from: "2.15.0"),
    ],
    targets: [
        .executableTarget(
            name: "Aureum",
            dependencies: [
                .product(name: "Hummingbird", package: "hummingbird")
            ]
        )
    ]
)
