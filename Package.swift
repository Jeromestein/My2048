// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "My2048Core",
    platforms: [
        .macOS(.v13),
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "My2048Core",
            targets: ["My2048Core"]
        )
    ],
    targets: [
        .target(
            name: "My2048Core",
            path: "My2048 Shared",
            exclude: [
                "Assets.xcassets",
                "GameScene.sks",
                "Actions.sks",
                "GameScene.swift"
            ],
            sources: [
                "Models",
                "ViewModels"
            ],
            publicHeadersPath: ""
        ),
        .testTarget(
            name: "My2048CoreTests",
            dependencies: ["My2048Core"],
            path: "My2048CoreTests"
        ),
        
    ]
)
