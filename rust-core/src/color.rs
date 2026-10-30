//! Per-style 3x3 color-correction matrices (row-major).
//!
//! Each matrix transforms linear-ish RGB. Values are original, not taken from
//! any other implementation.

use crate::CameraStyle;

/// A 3x3 color matrix in row-major order: [m00 m01 m02; m10 m11 m12; m20 m21 m22].
pub type ColorMatrix = [f32; 9];

/// Identity — pass-through color.
pub(crate) const NATURAL: ColorMatrix = [1.00, 0.00, 0.00, 0.00, 1.00, 0.00, 0.00, 0.00, 1.00];

/// Xiaomi-style: warm red lift, slightly crushed blues.
const XIAOMI: ColorMatrix = [1.06, 0.04, 0.00, 0.02, 1.02, 0.00, 0.00, 0.04, 0.92];

/// Oppo-style: cool blue lift, muted reds.
const OPPO: ColorMatrix = [0.94, 0.00, 0.00, 0.00, 1.00, 0.00, 0.05, 0.02, 1.08];

/// Vivo-style: warm skin tones, gentle overall lift.
const VIVO: ColorMatrix = [1.03, 0.03, 0.00, 0.01, 1.00, 0.00, 0.00, 0.02, 1.00];

/// Return the matrix for a style.
pub fn matrix_for(style: CameraStyle) -> ColorMatrix {
    match style {
        CameraStyle::Natural => NATURAL,
        CameraStyle::Xiaomi => XIAOMI,
        CameraStyle::Oppo => OPPO,
        CameraStyle::Vivo => VIVO,
    }
}

/// Apply a 3x3 matrix to one pixel (r, g, b in 0..=255), returning 0..=255.
pub fn apply_matrix(matrix: &ColorMatrix, r: f32, g: f32, b: f32) -> (f32, f32, f32) {
    let m = matrix;
    let out_r = m[0] * r + m[1] * g + m[2] * b;
    let out_g = m[3] * r + m[4] * g + m[5] * b;
    let out_b = m[6] * r + m[7] * g + m[8] * b;
    (out_r, out_g, out_b)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn natural_matrix_is_identity() {
        let m = matrix_for(CameraStyle::Natural);
        assert_eq!(m, [1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0]);
    }

    #[test]
    fn xiaomi_matrix_warms_reds() {
        let m = matrix_for(CameraStyle::Xiaomi);
        // Red channel should boost red input.
        assert!(m[0] > 1.0);
        // Blue channel should crush blue input.
        assert!(m[8] < 1.0);
    }

    #[test]
    fn oppo_matrix_cools_blues() {
        let m = matrix_for(CameraStyle::Oppo);
        assert!(m[8] > 1.0);
        assert!(m[0] < 1.0);
    }

    #[test]
    fn vivo_matrix_warms_skin() {
        let m = matrix_for(CameraStyle::Vivo);
        assert!(m[0] > 1.0);
    }

    #[test]
    fn apply_matrix_identity_passthrough() {
        let (r, g, b) = apply_matrix(&NATURAL, 100.0, 150.0, 200.0);
        assert_eq!((r, g, b), (100.0, 150.0, 200.0));
    }

    #[test]
    fn apply_matrix_xiaomi_boosts_red() {
        let (r, _g, _b) = apply_matrix(&XIAOMI, 100.0, 0.0, 0.0);
        assert!(r > 100.0);
    }
}
