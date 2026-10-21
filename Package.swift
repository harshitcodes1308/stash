// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Stash",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "Stash", targets: ["Stash"])],
    targets: [.executableTarget(name: "Stash")]
)
