# CameraApp — iPhone Camera with OEM Color Profiles

iPhone camera app with photo + video capture, Xiaomi/vivo/OPPO-inspired color profiles, and Zeiss watermark.
Built on Windows, compiled via GitHub Actions (macOS runner), installed as unsigned IPA via iLoader.

## Target Device

- **iPhone 11 Pro Max** (A13, iOS 15–18)
- Lenses: 0.5× ultra-wide, 1× wide, 2× telephoto
- No RAW / ProRAW (not supported on A13) — HEIF/JPEG photos, HEVC/H.264 video

## Project Structure

```
iphone-camera-app/
├── rust-core/                 # Rust processing core (aarch64-apple-ios)
│   ├── Cargo.toml
│   └── src/lib.rs             # C ABI: LUT (17³ + 512³), color matrix, tone curve, saturation, vignette, noise, watermark
│   └── src/lut_data.rs        # Style matrices: Natural, Xiaomi, OPPO, Vivo
├── ios-app/
│   ├── CameraApp/             # SwiftUI + AVFoundation iOS app
│   │   ├── CameraApp.swift        # App entry
│   │   ├── ContentView.swift      # Main camera UI (vivo/Xiaomi pattern)
│   │   ├── CameraView.swift       # AVFoundation session controller
│   │   ├── CameraViewRepresentable.swift  # SwiftUI ↔ UIKit bridge
│   │   ├── CameraViewModel.swift  # UI state + permissions
│   │   ├── CameraCoreBridge.swift # Swift ↔ Rust FFI bridge
│   │   ├── StylePickerView.swift  # Photo style bottom sheet
│   │   ├── SettingsView.swift     # Settings (watermark, style, format)
│   │   ├── ReviewView.swift       # Post-capture review
│   │   ├── PhotoLibrary.swift     # Save to Photos
│   │   ├── GalleryView.swift      # Last thumbnail
│   │   └── Assets.xcassets/       # Zeiss logo, LUT textures, ICC profile
│   │       ├── ZeissLogo.imageset/          # wm_zeiss_logo_default_v1.webp (vivo)
│   │       ├── ZeissVivoLogo.imageset/      # zeiss_vivo_logo.webp, effects_space_filter_zeiss_to_vivo.png (vivo)
│   │       └── LutData.imageset/            # hdrLut.png (Xiaomi), cartoon1_lut.png, DVRecordLut.png, DVScreenLut.png (vivo)
│   ├── CameraApp.xcodeproj/     # Xcode project
│   ├── Package.swift
│   └── Info.plist
├── .github/workflows/
│   └── ios-build.yml          # GitHub Actions: Rust iOS build → unsigned IPA
├── scripts/
│   └── extract_lut.py         # Derive 3D LUT from sample photos
└── README.md
```

## Reverse Engineering Sources

Extracted via `apktool` + `jadx` from:

| APK | File | Version | Status |
|-----|------|---------|--------|
| Xiaomi | `D:\xiaomi.apk` | MIUI Camera | ✅ Decompiled |
| vivo | `D:\vivo.apk` | vivo Camera | ✅ Decompiled |
| vivo | `D:\vivo-13.5.8.0.apk` | vivo Camera 13.5.8.0 | ✅ Decompiled |

### Key Assets Extracted

**From Xiaomi (`xiaomi.apk`):**
- `libMiFilterSDK.so` — CandySDK JNI interface (setLutBitmap, setWatermark, processBitmap, etc.)
- `assets/icc/wcg.icc` — ICC profile (sRGB EOTF, DCI-P3 gamut, Xiaomi 2022)
- `assets/cloudfilter/cloud_filter_*.json` — Filter definitions (LutSize=512)
- `assets/hdrLut.png` — HDR LUT texture
- `assets/watermarks/leica/` — Leica watermark templates

**From vivo (`vivo.apk`, `vivo-13.5.8.0.apk`):**
- `resources/res/drawable-*/wm_zeiss_logo_default_v1.webp` — Zeiss logo
- `resources/res/drawable-*/zeiss_vivo_logo.webp` — Zeiss+vivo logo
- `resources/res/drawable-*/zeiss_logo_driver.webp` — Zeiss driver logo
- `resources/res/drawable-*/pause_zeiss_logo.xml` — Pause screen Zeiss logo
- `resources/res/drawable-*/effects_space_filter_zeiss_to_vivo.png` — Zeiss→vivo filter
- `resources/assets/shader/base/fragment_lookup_table_512.glsl` — 512³ LUT shader
- `resources/assets/shader/base/fragment_ai_lookup_table.glsl` — AI LUT shader
- `resources/assets/cartoon1/cartoon1_lut.png` — 512³ LUT texture (246KB)
- `resources/assets/DVFilter/DVRecordLut.png` — Video record LUT (18KB)
- `resources/assets/DVFilter/DVScreenLut.png` — Video screen LUT (39KB)
- `res/values/colors.xml` — vivo camera colors (camera_gray_background #1b1b1b, camera_mode_color #2979ff, etc.)

## UI Design Source

Key elements reimplemented in SwiftUI from vivo layouts:

| Element | Source | Implementation |
|---------|--------|---------------|
| Shutter button | vivo `anim_shutter_button_pressed.xml` | Large centered circle, scale 1.0→0.9 on press |
| Zoom pills | vivo `zoom_button.xml` | Vertical 0.5×/1×/2× on left side |
| Top bar | vivo `top_bar_1_5_layout.xml` | Transparent, flash left, mode pills center, settings right |
| Recording indicator | vivo `video_module.xml` | Red dot + timer overlay at top |
| Watermark | vivo `watermark_small_banner_text.xml` | Bottom-right, Zeiss logo + ZEISS text |
| Colors | vivo `colors.xml` | Black bg (#1b1b1b), blue mode (#2979ff), theme (#f6cf40) |

## Color Profiles (Rust Core)

The Rust processing core applies color science per style:

| Style | Matrix | Gamma | Saturation | Vignette | Noise | Sharpen | Inspiration |
|-------|--------|-------|------------|----------|-------|---------|-------------|
| Natural | Identity | 1.0 | 1.0 | 0.0 | 0.0 | 0.0 | Default iPhone |
| Xiaomi | Warm red boost | 1.04 | 1.12 | 0.08 | 0.02 | 0.05 | Xiaomi MIUI vivid / libMiFilterSDK.so |
| OPPO | Cool blue lift | 1.02 | 1.08 | 0.05 | 0.01 | 0.08 | OPPO / Hasselblad crisp |
| Vivo | Warm skin tones | 1.0 | 1.05 | 0.06 | 0.015 | 0.03 | Vivo / Zeiss portrait |

Each style uses:
- A 3×3 color correction matrix (`glUniformMatrix3fv`)
- A 17³ or 512³ 3D LUT (`glTexImage3D` / `fragment_lookup_table_512.glsl`)
- Gamma tone curve
- Saturation, vignette, noise, sharpen effects

LUT textures bundled in the app:
- `hdrLut.png` — Xiaomi HDR LUT
- `cartoon1_lut.png` — vivo 512³ LUT texture
- `DVRecordLut.png` — vivo video record LUT
- `DVScreenLut.png` — vivo video screen LUT

## Watermark

The Zeiss logo (`wm_zeiss_logo_default_v1.webp`) was extracted from `vivo.apk` and bundled as `ZeissLogo` in `Assets.xcassets`.
When watermark is enabled, the Rust core alpha-blends it bottom-right (20px margin) on every saved photo/video frame.

## Build

### Prerequisites (Windows dev machine)

- Rust toolchain: `rustc 1.99.0`, `cargo 1.99.0`
- Java 26 (for apktool — already installed)
- Git

### Local Rust build (host check only)

```cmd
cd D:\fa\iphone-camera-app\rust-core
cargo build --release
```

This builds for the Windows host (x86_64) to verify compilation. The actual iOS build happens on GitHub Actions.

### GitHub Actions (macOS runner — produces unsigned IPA)

1. Push code to `main` branch or create a tag
2. GitHub Actions workflow (`.github/workflows/ios-build.yml`) will:
   - Add `aarch64-apple-ios` Rust target
   - Build `libcamera_core.a` for iOS
   - `xcodebuild` archive the Swift app (no code signing)
   - Strip `_CodeSignature` → unsigned IPA
   - Upload as release artifact

### Install via iLoader

1. On your jailbroken iPhone 11 Pro Max, install iLoader
2. Download the unsigned IPA from GitHub Releases (or workflow artifacts)
3. Transfer to iPhone (USB/AFC or HTTP)
4. Open iLoader → select IPA → Install
5. SpringBoard respring → app appears on home screen

**Requirements:** Jailbroken iOS device with iLoader. Unsigned IPA will not launch on stock, non-jailbroken iOS.

## Testing Checklist

- [ ] Photo capture (HEIF/JPEG) saves to Photos with style applied
- [ ] Video recording (HEVC/H.264) with timer and red indicator
- [ ] Lens switching: 0.5× / 1× / 2×
- [ ] Flash toggle: Auto / On / Off
- [ ] Style switching: Natural / Xiaomi / OPPO / Vivo
- [ ] Watermark on/off with Zeiss logo bottom-right
- [ ] Post-capture review screen with style badge
- [ ] Settings persist across launches
- [ ] Unsigned IPA installs and runs via iLoader on iPhone 11 Pro Max

## Legal / Personal Use

This app reverse-engineers UI layouts and color references from Xiaomi and vivo camera APKs for **personal use only**.
Do not redistribute extracted assets, native libraries, or the IPA publicly.
Brand names (Xiaomi, vivo, OPPO, Zeiss, Hasselblad, Leica) are used for reference only — not affiliated.