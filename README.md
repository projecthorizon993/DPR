# CameraApp — From-Scratch iPhone Camera

A clean-room iOS camera app built from the ground up with **no reused code**.

- **UI:** SwiftUI + AVFoundation (`UIViewControllerRepresentable`)
- **Processing core:** Rust (`staticlib` + `cdylib`), called through a C ABI bridge
- **Features:** photo capture, per-style color processing (color matrix, 3D LUT, tone curve), watermark, settings, post-capture review, save to Photos
- **Target:** iOS 15+, iPhone (built on macOS via `xcodebuild` / SPM)

This is an original implementation. No source was copied from any existing project.

## Layout

```
CameraApp/
├── Package.swift            # Swift Package Manager manifest
├── Info.plist               # App bundle metadata + usage descriptions
├── ios-app/CameraApp/       # SwiftUI + AVFoundation application code
├── rust-core/               # Rust image-processing core (aarch64-apple-ios)
│   ├── Cargo.toml
│   └── src/
├── scripts/                 # LUT / asset helpers
└── .github/workflows/       # CI: Rust iOS build → unsigned IPA
```

## Build

### Rust core (host check on any platform)

```cmd
cd D:\fa\rust-core
cargo build --release
```

### iOS app (macOS runner / Xcode)

```bash
cd D:\fa
xcodebuild -scheme CameraApp -configuration Release -destination 'generic/platform=iOS'
# or open Package.swift in Xcode
```

CI (`.github/workflows/ios-build.yml`) compiles the Rust core for `aarch64-apple-ios`,
builds the Swift package with `xcodebuild`, strips code signing, and publishes an
unsigned IPA for sideloading.

## License

Original work. Personal / educational use.
