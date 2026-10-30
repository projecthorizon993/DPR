"""Generate a preview of the per-style 3D LUT grids used by the Rust core.

This is a development/helper script only. The LUTs are generated procedurally
inside `rust-core/src/lut.rs` at runtime; nothing here is shipped in the app.
"""
from __future__ import annotations

import json

DIM = 17


def lut_offsets(style: str):
    grid = []
    inv = DIM - 1
    for iz in range(DIM):
        for iy in range(DIM):
            for ix in range(DIM):
                r = ix / inv
                g = iy / inv
                b = iz / inv
                if style == "Natural":
                    dr, dg, db = 0.0, 0.0, 0.0
                elif style == "Xiaomi":
                    warm = max(0.0, min(1.0, r - b))
                    mid = max(0.0, min(1.0,
                        1.0 - abs(r - 0.5) - abs(g - 0.5) - abs(b - 0.5)))
                    dr = 0.06 * warm + 0.02 * mid
                    dg = 0.01 * mid
                    db = -0.04 * warm
                elif style == "Oppo":
                    cool = max(0.0, min(1.0, b - r))
                    dr = -0.04 * cool
                    dg = 0.01 * cool
                    db = 0.06 * cool
                elif style == "Vivo":
                    skin = max(0.0, min(1.0, (r * 0.7 + g * 0.3) - b))
                    mid = max(0.0, min(1.0,
                        1.0 - abs(r - 0.5) - abs(g - 0.5)))
                    dr = 0.05 * skin * mid
                    dg = 0.02 * skin * mid
                    db = 0.0
                else:
                    raise ValueError(style)
                grid.append([round(dr * 255, 3), round(dg * 255, 3), round(db * 255, 3)])
    return grid


def main():
    out = {style: lut_offsets(style) for style in
           ("Natural", "Xiaomi", "Oppo", "Vivo")}
    with open("lut_preview.json", "w") as f:
        json.dump(out, f, indent=2)
    print(f"Wrote lut_preview.json with {len(out)} styles x {DIM**3} nodes")


if __name__ == "__main__":
    main()
