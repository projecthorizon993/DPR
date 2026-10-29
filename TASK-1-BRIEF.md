Task 1: Fix dangling pointer in CameraStyle.renderParams()

## Context
File: D:\fa\iphone-camera-app\ios-app/CameraApp/Services/CameraCoreBridge.swift
Lines: 326-358

## Problem
The `renderParams()` method uses `matrix.withUnsafeBufferPointer { $0.baseAddress }` to return an `UnsafePointer<Float>`. However, `withUnsafeBufferPointer` is only valid inside the closure — the pointer becomes dangling immediately after the closure returns. This is undefined behavior that may appear to work but will crash or produce corrupted colors on the jailbroken iPhone.

## Requirements
1. Fix `renderParams()` so all four cases (.natural, .xiaomi, .oppo, .vivo) return valid pointers that outlive the function call
2. Store color matrices as `static let` constants on `CameraStyle` so they persist for the program lifetime
3. Return `UnsafePointer<Float>` pointing to those static buffers
4. All matrices must remain exactly the same values (from reverse-engineered Xiaomi/OPPO/Vivo color profiles)
5. .natural returns (nil, 1.0) — no change needed

## Current matrices (do not change values)
- .xiaomi: [1.10, 0.03, -0.05, -0.02, 1.05, 0.01, -0.03, -0.02, 1.07], gamma 1.04
- .oppo: [1.03, -0.01, -0.04, 0.00, 1.07, -0.02, -0.04, -0.01, 1.05], gamma 1.02
- .vivo: [1.07, 0.01, -0.02, 0.01, 1.03, -0.03, -0.02, -0.04, 1.06], gamma 1.0

## Acceptance Criteria
- `renderParams()` compiles without errors
- No `withUnsafeBufferPointer` returning pointer outside closure
- All matrices accessible via static storage
- Pointer remains valid for duration of `process_photo()` FFI call
- No new files needed — only edit CameraCoreBridge.swift

## Before You Begin
- Read CameraCoreBridge.swift lines 1-374 to understand the full context
- Read rust-core/src/lib.rs to understand how the matrix pointer is used in Rust (it's used immediately in process_photo via apply_color_matrix)
- If anything is unclear, ask before implementing

## Your Job
1. Implement the fix for renderParams()
2. Commit your work
3. Self-review
4. Report back with status, commits, test summary, concerns

Work from: D:\fa\iphone-camera-app

Report file: D:\fa\iphone-camera-app/TASK-1-REPORT.md
