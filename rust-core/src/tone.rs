//! Gamma tone-curve parameters per style.

use crate::CameraStyle;

/// Gamma exponent per style (1.0 = linear).
pub fn gamma_for(style: CameraStyle) -> f32 {
    match style {
        CameraStyle::Natural => 1.00,
        CameraStyle::Xiaomi => 1.04,
        CameraStyle::Oppo => 1.02,
        CameraStyle::Vivo => 1.00,
    }
}

/// Apply gamma: out = 255 * (in / 255)^(1/gamma), clamped to 0..=255.
pub fn apply_gamma(value: f32, gamma: f32) -> f32 {
    if gamma <= 0.0 {
        return value.clamp(0.0, 255.0);
    }
    let t = (value / 255.0).clamp(0.0, 1.0);
    255.0 * t.powf(1.0 / gamma)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn gamma_one_is_identity() {
        assert_eq!(apply_gamma(0.0, 1.0), 0.0);
        assert_eq!(apply_gamma(127.5, 1.0), 127.5);
        assert_eq!(apply_gamma(255.0, 1.0), 255.0);
    }

    #[test]
    fn gamma_greater_than_one_brightens_midtones() {
        // Gamma > 1 lifts midtones (curve bows below linear).
        let mid = apply_gamma(127.5, 2.0);
        assert!(mid > 127.5);
    }

    #[test]
    fn gamma_clamped_to_bounds() {
        assert_eq!(apply_gamma(-10.0, 1.0), 0.0);
        assert_eq!(apply_gamma(300.0, 1.0), 255.0);
    }

    #[test]
    fn black_stays_black() {
        assert_eq!(apply_gamma(0.0, 100.0), 0.0);
    }

    #[test]
    fn white_stays_white() {
        assert_eq!(apply_gamma(255.0, 100.0), 255.0);
    }

    #[test]
    fn gamma_for_natural_is_one() {
        assert_eq!(gamma_for(CameraStyle::Natural), 1.0);
    }

    #[test]
    fn gamma_for_xiaomi_is_above_one() {
        assert!(gamma_for(CameraStyle::Xiaomi) > 1.0);
    }
}
