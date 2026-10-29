# SDD ledger — plan: D:\fa\iphone-camera-app

BASE: a545e45 (Fix: Add feedback.md project knowledge dump and documentation)

## Pre-flight Scan Results
Tasks sharing files (resolved by sequential execution):
- Task 1 (renderParams) → CameraCoreBridge.swift ← Task 8 (import SwiftUI) — SAME FILE, sequential OK
- Task 2 (shutter) → CameraView.swift ← Task 3 (watermark), Task 9 (resolution), Tasks 10-16 (Xiaomi UI) — SAME FILE, sequential OK
- Task 3 (watermark) → RAWProcessorService.swift — standalone, no conflict
- Task 4 (Xcode version) → ios-build.yml — standalone
- Task 5 (Info.plist path) → project.pbxproj + root Info.plist — standalone
- Task 6 (.gitignore) → .gitignore — standalone
- Task 7 (Chinese text) → Multiple Swift files — overlaps with Tasks 2, 9-16 on CameraView.swift; do after UI tasks

Ruling: All conflicts resolved by sequential execution order. Proceed with Task 1.

## Tasks
1. [x] Fix dangling pointer in renderParams() — CameraCoreBridge.swift:326-358 (CRITICAL) — COMPLETE (f33c3f9, APPROVED)
2. [ ] Shutter button amber #FFFFCE16 not white — CameraView.swift:496 (CRITICAL) — IN PROGRESS
3. [ ] Zeiss watermark never applied (nil) — CameraView.swift:72, RAWProcessorService.swift:72 (CRITICAL)
4. [ ] GitHub Actions Xcode 15 for iOS 18 — ios-build.yml:18 (CRITICAL)
5. [ ] Info.plist path mismatch — project.pbxproj vs root Info.plist (CRITICAL)
6. [ ] Add rust-libs/*.a to .gitignore — .gitignore (SHOULD)
7. [ ] Translate Chinese UI text to English — Multiple Swift files (SHOULD)
8. [ ] Move import SwiftUI to top — CameraCoreBridge.swift:363 (MINOR)
9. [ ] Dynamic camera resolution instead of hardcoded — CameraView.swift:896,989 (MINOR)
10. [ ] Mode pills PHOTO/VIDEO top center (amber fill + dark text selected) — CameraView.swift (XIAOMI PORT)
11. [ ] Flash toggle top-left amber when ON — CameraView.swift (XIAOMI PORT)
12. [ ] Settings top-right ellipsis icon — CameraView.swift (XIAOMI PORT)
13. [ ] Lens pills vertical left side (0.5×/1×/2×, amber fill selected) — CameraView.swift (XIAOMI PORT)
14. [ ] Gallery shortcut bottom-left with thumbnail — CameraView.swift (XIAOMI PORT)
15. [ ] Recording indicator top-right red pulsing dot + timer — CameraView.swift (XIAOMI PORT)
16. [ ] Style selector bottom-right circle accent dot + initials — CameraView.swift (XIAOMI PORT)

## Rules
- One implementer subagent per task, never parallel
- Task review after each implementer (spec + quality)
- Fix loop on review findings until clean or cap
- Push only after all tasks complete and review passes
- If push fails, retry once; if still fails, pivot approach
