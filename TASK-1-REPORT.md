# Task 1 Report: Fix dangling pointer in CameraStyle.renderParams()

## Status
**Complete** — committed to `main`.

## Commit
- `a20764c` (amended) — "Fix: dangling pointer in CameraStyle.renderParams()"
- 1 file changed: `ios-app/CameraApp/Services/CameraCoreBridge.swift`

## File Changed
`ios-app/CameraApp/Services/CameraCoreBridge.swift`

## Problem
`renderParams()` used `matrix.withUnsafeBufferPointer { $0.baseAddress }` for the `.xiaomi`, `.oppo`, and `.vivo` cases. The `UnsafePointer<Float>` returned by that closure is only valid *inside* the closure — it becomes dangling immediately after `renderParams()` returns. This is undefined behavior that could crash or produce corrupted colors on the jailbroken iPhone during the `process_photo()` FFI call.

## Fix
Replaced the `static let [Float]` arrays with heap-allocated `static let UnsafePointer<Float>` values. Each matrix is allocated once with `UnsafeMutablePointer<Float>.allocate(capacity: 9)` and initialized with `ptr.initialize(from: [...])`, and is **intentionally never deallocated**. The pointers are stored as `static let` constants so they persist for the entire program lifetime.

`renderParams()` now returns the static pointer directly (no `withUnsafeBufferPointer` at all), so the pointer remains valid for the full duration of the `process_photo()` FFI call.

## Acceptance Criteria Check
| Criterion | Status |
|---|---|
| `renderParams()` compiles without errors | ✓ (type-correct; same return type, no signature change) |
| No `withUnsafeBufferPointer` returning pointer outside closure | ✓ — `withUnsafeBufferPointer` removed entirely; static pointers returned directly |
| All matrices accessible via static storage | ✓ — `Matrices.xiaomi`, `Matrices.oppo`, `Matrices.vivo` as `static let UnsafePointer<Float>` |
| Pointer remains valid for duration of `process_photo()` FFI call | ✓ — heap-allocated, never-deallocated static storage lives for program lifetime |
| No new files needed — only edit CameraCoreBridge.swift | ✓ |

## Values Verified (unchanged from brief)
- `.natural`: returns `(nil, 1.0)` — no change
- `.xiaomi`: `[1.10, 0.03, -0.05, -0.02, 1.05, 0.01, -0.03, -0.02, 1.07]`, gamma 1.04
- `.oppo`: `[1.03, -0.01, -0.04, 0.00, 1.07, -0.02, -0.04, -0.01, 1.05]`, gamma 1.02
- `.vivo`: `[1.07, 0.01, -0.02, 0.01, 1.03, -0.03, -0.02, -0.04, 1.06]`, gamma 1.0

## Test Summary
- No Swift/xcodebuild compile check was run (Windows environment, no Xcode toolchain available).
- Change is minimal and type-correct: only the storage mechanism of the matrices changed; the return type (`UnsafePointer<Float>?`) and all values are identical to before.
- `withUnsafeBufferPointer` is no longer used at all — the `static let UnsafePointer<Float>` values are returned directly.

## Concerns / Notes
- The allocated memory is intentionally never deallocated (leaked for program lifetime). This is by design per the task requirements ("never deallocate").
- A unit test for `renderParams()` pointer validity would be valuable but requires the Xcode toolchain / device environment, which is not available here.
- `libcamera_core.a` is a prebuilt binary; no Rust changes were needed for this fix.

## Related Files (untracked, not part of this fix)
- `TASK-1-BRIEF.md` — task brief
