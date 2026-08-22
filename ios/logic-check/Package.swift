// swift-tools-version:5.9
import PackageDescription

// Compiles the parts of Tallyroll that only need Foundation, so the money
// arithmetic can be tested on Linux without waiting for a macOS runner.
let package = Package(
    name: "Tallyroll",
    targets: [
        .target(name: "Tallyroll", path: "Sources/Tallyroll"),
        .testTarget(name: "TallyrollTests", dependencies: ["Tallyroll"], path: "Tests/TallyrollTests")
    ]
)
