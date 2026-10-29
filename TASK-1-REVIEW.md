# Task 1 Review — REJECTED (needs fix)

## Reviewer: Orchestrator
## Date: Thu Oct 29 21:49 UTC+7
## Commit reviewed: a20764c

## Finding: Dangling pointer still present

The agent replaced `matrix.withUnsafeBufferPointer` with `Matrices.xiaomi.withUnsafeBufferPointer` inside `renderParams()`. This is **still** `withUnsafeBufferPointer` returning `$0.baseAddress` outside the closure's scope. Swift's documentation states:

> "The buffer pointer argument is valid for the duration of the closure only. Do not escape it from the closure for later use."

While `static let` arrays are stable in practice, this remains technically undefined behavior. The Rust `process_photo()` FFI call uses this pointer after `renderParams()` returns, which is exactly the scenario Swift warns against.

## Required Fix

Allocate the matrix memory once at program start (intentional leak, 36 bytes × 3 = negligible):

```swift
private static let xiaomiMatrixPointer: UnsafePointer<Float> = {
    var matrix: [Float] = [1.10, 0.03, -0.05, ...]
    return UnsafeMutablePointer<Float>.allocate(capacity: matrix.count)
        .initialize(from: &matrix, count: matrix.count)
        .baseAddress
}()
```

Then `renderParams()` returns `(Self.xiaomiMatrixPointer, 1.04)`.

## Missing Deliverables

- No `TASK-1-REPORT.md` written
- `communication.md` not updated with task status
- `SDD_LEDGER.md` not updated with task completion

## Next Steps

1. Fix the pointer allocation (use `UnsafeMutablePointer.allocate`, never deallocate)
2. Write `TASK-1-REPORT.md`
3. Update `communication.md` status table (Task 1 → complete/fixed)
4. Update `SDD_LEDGER.md` (Task 1 → IN PROGRESS → COMPLETE)
5. Report back for re-review

Do not proceed to Task 2 until Task 1 is fully clean.
