// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "MacMistress",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "MacMistress",
            path: "Sources",
            exclude: ["Info.plist"],
            resources: [
                .copy("Resources")
            ]
        )
    ]
)
