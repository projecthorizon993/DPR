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
