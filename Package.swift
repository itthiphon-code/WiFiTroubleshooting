// swift-tools-version: 6.0
import PackageDescription
let package = Package(
    name: "WiFiTroubleshooting",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "WiFiTroubleshooting", targets: ["WiFiTroubleshooting"])],
    targets: [
        .target(name: "WiFiCore"),
        .executableTarget(name: "WiFiTroubleshooting", dependencies: ["WiFiCore"]),
        .executableTarget(name: "WiFiCoreChecks", dependencies: ["WiFiCore"], path: "Tests/WiFiCoreTests")
    ],
    swiftLanguageModes: [.v5]
)
