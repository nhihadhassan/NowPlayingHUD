// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "NowPlayingHUD",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "NowPlayingHUD", targets: ["NowPlayingHUD"]),
        .library(name: "NowPlayingHUDKit", targets: ["NowPlayingHUDKit"])
    ],
    dependencies: [
        // Zero third-party dependencies by design. See README "Dependencies".
    ],
    targets: [
        .target(
            name: "NowPlayingHUDKit",
            dependencies: []
        ),
        .executableTarget(
            name: "NowPlayingHUD",
            dependencies: ["NowPlayingHUDKit"]
        ),
        // A plain executable, not a `.testTarget` — see `Tests/NowPlayingHUDKitTests/MiniTest.swift`
        // for why: this machine has no full Xcode install, and `swift test` was verified (with a
        // deliberately-failing assertion) to build and link successfully but never actually run
        // the resulting test bundle. `swift run NowPlayingHUDKitTests` sidesteps that entirely.
        .executableTarget(
            name: "NowPlayingHUDKitTests",
            dependencies: ["NowPlayingHUDKit"],
            path: "Tests/NowPlayingHUDKitTests"
        )
    ]
)
