// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PlainText",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "PlainText", targets: ["PlainText"])],
    targets: [
        .executableTarget(name: "PlainText")
    ],
    swiftLanguageModes: [.v5]
)
