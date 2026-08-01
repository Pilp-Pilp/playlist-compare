// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "PlaylistOrganizer",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "PlaylistOrganizer",
            path: "Sources/PlaylistOrganizer"
        )
    ]
)
