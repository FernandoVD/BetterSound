// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "BetterSound",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "BetterSound",
            path: "Sources/BetterSound",
            linkerSettings: [
                .linkedFramework("CoreAudio"),
                .linkedFramework("AudioToolbox"),
                .linkedFramework("ServiceManagement"),
                .linkedFramework("AppKit"),
                .linkedFramework("SwiftUI")
            ]
        )
    ]
)
