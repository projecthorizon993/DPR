# Changelog

All notable changes to CameraApp are documented in this file.

## [Unreleased]

### Added
- SwiftUI + AVFoundation iOS camera app built from scratch (no code reuse)
- Rust image-processing core (`camera-core`) with C ABI: per-style color matrix,
  3D LUT, gamma tone curve, and alpha-blended watermark
- Live camera preview with real-time styled frame overlay
- Photo capture with style processing (Natural / Xiaomi / Oppo / Vivo)
- Video recording with start/stop and recording indicator
- Lens switching (0.5× ultra-wide, 1× wide, 2× telephoto)
- Flash toggle (off / on / auto) with torch control
- Style picker, settings (watermark toggle, photo format), post-capture review
- Watermark blending on saved photos via Rust `camera_blend_watermark`
- Photo format selection (HEIF / JPEG)
- Settings persistence via `@AppStorage`
- Save to photo library with watermark applied
- 34 Rust unit tests covering color matrices, tone curve, LUT sampling,
  image pipeline, watermark blending, and C ABI error handling
- Swift unit tests for CameraStyle, CameraLens, FlashMode, defaults
- GitHub Actions CI: Rust fmt/clippy/test, Rust iOS build, xcodebuild iOS build

### Changed
- Replaced `NavigationStack` with `NavigationView` for iOS 15 compatibility
- CameraViewModel inherits `NSObject` for delegate protocol conformance

### Fixed
- C ABI write-back: `camera_process_frame` and `camera_blend_watermark` now write
  processed pixels back to the caller's buffer
- `NavigationStack` unavailable on iOS 15 → `NavigationView`
- `startRecording(to:delegate:)` → `startRecording(to:recordingDelegate:)`
- `CameraStyle(rawValue:)` returns optional → pass `rawValue` (Int32) directly
- `initialize(from:count:)` on buffer pointer → byte copy loop

## [1.0.0] - 2026-10-30

### Added
- Initial release: from-scratch iPhone camera app with Rust processing core
- PR #1 merged into `main`
