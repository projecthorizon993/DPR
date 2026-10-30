// swift-tools-version: 5.8
import PackageDescription

let package = Package(
    name: "JustRaw",
    platforms: [
        .iOS(.v15)
    ],
    products: [
        .executable(name: "JustRaw", targets: ["JustRaw"])
    ],
    targets: [
        .executableTarget(
            name: "JustRaw",
            path: ".",
            exclude: ["Package.swift", "Package.resolved"],
            linkerSettings: [
                .linkedLibrary("camera_core", .when(platforms: [.iOS]))
            ]
        )
    ]
)
