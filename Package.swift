// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "SimpleBrowser",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "SimpleBrowser", targets: ["SimpleBrowser"])
    ],
    targets: [
        .executableTarget(name: "SimpleBrowser")
    ]
)
