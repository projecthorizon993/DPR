// swift-tools-version: 5.8
import PackageDescription

let package = Package(
    name: "CameraApp",
    platforms: [
        .iOS(.v15)
    ],
    products: [
        .executable(name: "CameraApp", targets: ["CameraApp"])
    ],
    targets: [
        .executableTarget(
            name: "CameraApp",
            path: ".",
            exclude: ["Package.swift", "Package.resolved"],
            linkerSettings: [
                .linkedLibrary("camera_core", .when(platforms: [.iOS]))
            ]
        )
    ]
)
