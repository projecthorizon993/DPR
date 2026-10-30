// swift-tools-version: 5.9
// CameraApp — from-scratch iOS camera application.
// No code reused from any existing project.
import PackageDescription

let package = Package(
    name: "CameraApp",
    defaultLocalization: "en",
    platforms: [.iOS(.v15)],
    products: [
        // The main application bundle is produced by the Xcode project /
        // xcodebuild rather than a SwiftPM product, but we declare the library
        // target so the sources are compiled and linked as a module.
        .library(name: "CameraApp", targets: ["CameraApp"]),
    ],
    dependencies: [],
    targets: [
        .target(
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
