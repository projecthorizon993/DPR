// swift-tools-version: 5.9
// CameraApp — from-scratch iOS camera application.
// No code reused from any existing project.
import PackageDescription

let package = Package(
    name: "CameraApp",
    defaultLocalization: "en",
    platforms: [.iOS(.v15)],
    products: [
        // The main application bundle is produced by xcodebuild from the
        // executable target; no separate SwiftPM library product is needed.
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "CameraApp",
            dependencies: [],
            path: "ios-app/CameraApp",
            exclude: ["Info.plist"]
        ),
        .testTarget(
            name: "CameraAppTests",
            dependencies: ["CameraApp"],
            path: "ios-app/CameraAppTests"
        ),
    ]
)
