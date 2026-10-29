# Communication.md — Orchestrator/Reviewer ↔ Implementer Coordination

## Roles

**Orchestrator/Reviewer (me):**
- Maintains the task ledger and SDD plan
- Reviews every code change before push
- Runs build verification (GitHub Actions status)
- Decides fix-loop vs. pivot on failures
- Authorizes push only when all tasks are clean

**Implementer (your agent session):**
- Executes tasks from the SDD ledger one at a time
- Reports status via this file and TASK-*-REPORT.md files
- Never pushes directly — push is the reviewer's decision

## Current State

- Repo: `https://github.com/projecthorizon993/DPR`, branch `main`
- Local: `D:\fa\iphone-camera-app`
- BASE commit: `a545e45` (Add feedback.md)
- Working tree: clean

## Critical Bugs to Fix (in order)

1. **Dangling pointer in `renderParams()`** — `CameraCoreBridge.swift:326-358`
   - `withUnsafeBufferPointer` returns dangling pointer → UB, crashes on device
   - Fix: store matrices as `static let`, return pointer to static buffer

2. **Shutter button white instead of amber `#FFFFCE16`** — `CameraView.swift:496`
   - Change `Color.white` → `Color(hex: "FFFFCE16")`

3. **Zeiss watermark never applied (`nil`)** — `CameraView.swift`, `RAWProcessorService.swift`
   - Load `UIImage(named: "ZeissLogo")` and pass as watermark

4. **GitHub Actions uses Xcode 15, project targets iOS 18** — `ios-build.yml:18`
   - Change to Xcode 16+

5. **Info.plist path mismatch** — `project.pbxproj` vs root `Info.plist`
   - Move Info.plist into `ios-app/CameraApp/` or fix pbxproj path

## Xiaomi MIUI Features to Port

6. Mode pills PHOTO/VIDEO top center (amber fill + dark text selected)
7. Flash toggle top-left (amber when ON)
8. Settings top-right (ellipsis icon)
9. Lens pills vertical left side (0.5×/1×/2×)
10. Gallery shortcut bottom-left with thumbnail
11. Recording indicator top-right (red pulsing dot + timer)
12. Style selector bottom-right circle with accent dot + initials
13. Pro mode + other camera modes

## Communication Protocol

1. Implementer writes task brief, implements, commits, writes TASK-N-REPORT.md
2. Implementer updates this file with status
3. Reviewer reviews the diff, approves or requests fixes
4. Reviewer pushes only when all tasks are clean
5. If push fails → retry once → if still fails, pivot approach

## Status Tracking

| Task | Status | Commit | Report | Review |
|------|--------|--------|--------|--------|
| 1. renderParams dangling pointer | COMPLETE | f33c3f9 | TASK-1-REPORT.md | APPROVED |
| 2. Shutter amber #FFFFCE16 | IN PROGRESS | | | |
| 3. Zeiss watermark applied | pending | | | |
| 4. Xcode 16 in CI | pending | | | |
| 5. Info.plist path fix | pending | | | |
| 6-13. Xiaomi UI port | pending | | | |

## Notes for Implementer

- Work from: `D:\fa\iphone-camera-app`
- Never push — push is reviewer's decision
- If blocked, write BLOCKED status with specifics here
- Rate limit: keep API requests under 40/min if running parallel subagents
- Do not commit/push without reviewer approval
