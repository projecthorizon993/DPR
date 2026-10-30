//! Per-style 3D LUT with trilinear sampling.
//!
//! Each style owns a 17x17x17 grid (4913 nodes) of RGB offsets, generated
//! procedurally so no asset file is required. The grid is built once and cached.

use crate::CameraStyle;
use std::sync::OnceLock;

const LUT_DIM: usize = 17;
const LUT_NODES: usize = LUT_DIM * LUT_DIM * LUT_DIM; // 4913
type LutGrid = [[f32; 3]; LUT_NODES];

static LUTS: [OnceLock<LutGrid>; 4] = [
    OnceLock::new(), // Natural
    OnceLock::new(), // Xiaomi
    OnceLock::new(), // Oppo
    OnceLock::new(), // Vivo
];

/// Build the 3D LUT grid for a style. Each node holds an RGB offset.
fn build_lut(style: CameraStyle) -> LutGrid {
    let mut grid = [[0.0; 3]; LUT_NODES];
    let inv = (LUT_DIM - 1) as f32;

    for iz in 0..LUT_DIM {
        for iy in 0..LUT_DIM {
            for ix in 0..LUT_DIM {
                let i = iz * LUT_DIM * LUT_DIM + iy * LUT_DIM + ix;
                let r = ix as f32 / inv;
                let g = iy as f32 / inv;
                let b = iz as f32 / inv;

                let (dr, dg, db) = match style {
                    CameraStyle::Natural => (0.0, 0.0, 0.0),
                    CameraStyle::Xiaomi => {
                        // Warm shift: push reds up, blues down, slight saturation of midtones.
                        let warm = (r - b).clamp(0.0, 1.0);
                        let mid = (1.0 - (r - 0.5).abs() - (g - 0.5).abs() - (b - 0.5).abs())
                            .clamp(0.0, 1.0);
                        (0.06 * warm + 0.02 * mid, 0.01 * mid, -0.04 * warm)
                    }
                    CameraStyle::Oppo => {
                        // Cool shift: blues up, reds down.
                        let cool = (b - r).clamp(0.0, 1.0);
                        (-0.04 * cool, 0.01 * cool, 0.06 * cool)
                    }
                    CameraStyle::Vivo => {
                        // Gentle skin-tone warmth: favor red/green in midrange.
                        let skin = ((r * 0.7 + g * 0.3) - b).clamp(0.0, 1.0);
                        let mid = (1.0 - (r - 0.5).abs() - (g - 0.5).abs()).clamp(0.0, 1.0);
                        (0.05 * skin * mid, 0.02 * skin * mid, 0.0)
                    }
                };
                grid[i] = [dr * 255.0, dg * 255.0, db * 255.0];
            }
        }
    }
    grid
}

fn grid_for(style: CameraStyle) -> &'static LutGrid {
    let idx = match style {
        CameraStyle::Natural => 0,
        CameraStyle::Xiaomi => 1,
        CameraStyle::Oppo => 2,
        CameraStyle::Vivo => 3,
    };
    LUTS[idx].get_or_init(|| build_lut(style))
}

/// Return the LUT grid for a style (built lazily, cached forever).
pub fn lut_for(style: CameraStyle) -> &'static LutGrid {
    grid_for(style)
}

/// Trilinear sample the LUT at normalized RGB (0..1), returning an RGB offset in 0..255.
pub fn sample_lut(grid: &LutGrid, r: f32, g: f32, b: f32) -> (f32, f32, f32) {
    let inv = (LUT_DIM - 1) as f32;
    let rf = r * inv;
    let gf = g * inv;
    let bf = b * inv;

    let r0 = rf.floor() as i32;
    let g0 = gf.floor() as i32;
    let b0 = bf.floor() as i32;
    let r1 = (r0 + 1).clamp(0, LUT_DIM as i32 - 1);
    let g1 = (g0 + 1).clamp(0, LUT_DIM as i32 - 1);
    let b1 = (b0 + 1).clamp(0, LUT_DIM as i32 - 1);

    let fr = rf - r0 as f32;
    let fg = gf - g0 as f32;
    let fb = bf - b0 as f32;

    fn node(grid: &LutGrid, x: i32, y: i32, z: i32) -> [f32; 3] {
        let i = z as usize * LUT_DIM * LUT_DIM + y as usize * LUT_DIM + x as usize;
        grid[i]
    }

    let c000 = node(grid, r0, g0, b0);
    let c100 = node(grid, r1, g0, b0);
    let c010 = node(grid, r0, g1, b0);
    let c110 = node(grid, r1, g1, b0);
    let c001 = node(grid, r0, g0, b1);
    let c101 = node(grid, r1, g0, b1);
    let c011 = node(grid, r0, g1, b1);
    let c111 = node(grid, r1, g1, b1);

    let mut out = [0.0; 3];
    for c in 0..3 {
        let c00 = c000[c] * (1.0 - fr) + c100[c] * fr;
        let c10 = c010[c] * (1.0 - fr) + c110[c] * fr;
        let c01 = c001[c] * (1.0 - fr) + c101[c] * fr;
        let c11 = c011[c] * (1.0 - fr) + c111[c] * fr;
        let c0 = c00 * (1.0 - fg) + c10 * fg;
        let c1 = c01 * (1.0 - fg) + c11 * fg;
        out[c] = c0 * (1.0 - fb) + c1 * fb;
    }
    (out[0], out[1], out[2])
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn natural_lut_is_all_zeros() {
        let grid = lut_for(CameraStyle::Natural);
        for node in grid.iter() {
            assert_eq!(*node, [0.0, 0.0, 0.0]);
        }
    }

    #[test]
    fn sample_lut_natural_is_zero_offset() {
        let grid = lut_for(CameraStyle::Natural);
        let (dr, dg, db) = sample_lut(grid, 0.5, 0.5, 0.5);
        assert_eq!((dr, dg, db), (0.0, 0.0, 0.0));
    }

    #[test]
    fn sample_lut_clamped_at_corners() {
        let grid = lut_for(CameraStyle::Xiaomi);
        // Black corner.
        let (r, g, b) = sample_lut(grid, 0.0, 0.0, 0.0);
        assert!(r.is_finite() && g.is_finite() && b.is_finite());
        // White corner.
        let (r, g, b) = sample_lut(grid, 1.0, 1.0, 1.0);
        assert!(r.is_finite() && g.is_finite() && b.is_finite());
    }

    #[test]
    fn xiaomi_lut_warms_reds_over_blues() {
        let grid = lut_for(CameraStyle::Xiaomi);
        // Where red > blue, red is pushed up and blue is pushed down.
        let (dr_red, _, _) = sample_lut(grid, 0.8, 0.0, 0.4);
        let (_, _, db_blue) = sample_lut(grid, 0.8, 0.0, 0.4);
        assert!(dr_red > 0.0);
        assert!(db_blue < 0.0);
    }

    #[test]
    fn lut_grid_has_correct_size() {
        let grid = lut_for(CameraStyle::Natural);
        assert_eq!(grid.len(), LUT_NODES);
    }
}
