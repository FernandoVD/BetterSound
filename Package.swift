// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "BetterSound",
    platforms: [.macOS(.v15)],
    targets: [
        .executableTarget(
            name: "BetterSound",
            path: "Sources/BetterSound",
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ],
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
