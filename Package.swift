// swift-tools-version: 5.9
import PackageDescription
let package = Package(
    name: "TimetableCore",
    platforms: [.macOS(.v13)],
    targets: [
        .target(name: "TimetableCore", path: "Shared"),
        .testTarget(name: "TimetableCoreTests", dependencies: ["TimetableCore"], path: "Tests", resources: [.copy("Fixtures")])
    ]
)
