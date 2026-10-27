//! LUT and color processing data derived from Xiaomi libMiFilterSDK.so
//!
//! Extracted shader parameters from libMiFilterSDK.so (CandySDK):
//!   - CubeLutEffect::addLutEffectData - 3D LUT texture
//!   - glUniformMatrix3fv - color correction matrix
//!   - glTexImage3D/glTexSubImage3D - 3D LUT texture upload
//!   - Highlight/shadow color blending with multiply/colorBurn blend modes
//!   - Vignette, NoiseStrength, SharpenIntensity, Saturation effects
//!
//! Xiaomi color palette from shader (highlight/shadow tints):
//!   col_red_highlight   = vec4(1.0, 0.7412, 0.7412, 1.0)
//!   col_orange_highlight= vec4(1.00, 0.78, 0.65, 1.0)
//!   col_blue_highlight  = vec4(0.70, 0.93, 1.00, 1.0)
//!   col_yellow_highlight= vec4(1.00, 0.93, 0.70, 1.0)
//!   col_green_highlight = vec4(0.75, 1.00, 0.93, 1.0)
//!   col_purple_highlight= vec4(0.91, 0.80, 1.00, 1.0)

use crate::apply_color_matrix;

/// Generate a 17^3 3D LUT by applying the color matrix to each grid node.
/// Output: flat array of `size^3 * 3` f32 values in [0,1].
pub fn generate_lut_from_matrix(matrix: &[f32; 9], size: usize) -> Vec<f32> {
    let mut lut = Vec::with_capacity(size * size * size * 3);

    for r in 0..size {
        let rf = r as f32 / (size - 1) as f32;
        for g in 0..size {
            let gf = g as f32 / (size - 1) as f32;
            for b in 0..size {
                let bf = b as f32 / (size - 1) as f32;

                let nr = rf * matrix[0] + gf * matrix[1] + bf * matrix[2];
                let ng = rf * matrix[3] + gf * matrix[4] + bf * matrix[5];
                let nb = rf * matrix[6] + gf * matrix[7] + bf * matrix[8];

                lut.push(nr.clamp(0.0, 1.0));
                lut.push(ng.clamp(0.0, 1.0));
                lut.push(nb.clamp(0.0, 1.0));
            }
        }
    }

    lut
}

/// Predefined color matrices derived from Xiaomi cloud_filter analysis
/// and libMiFilterSDK.so shader parameters.
pub struct StyleMatrix {
    pub matrix: [f32; 9],
    pub gamma: f32,
    pub lut_size: usize, // 0 = no LUT, use matrix only
    pub saturation: f32,
    pub vignette: f32,
    pub noise: f32,
    pub sharpen: f32,
}

impl StyleMatrix {
    pub fn natural() -> Self {
        Self {
            matrix: [1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0],
            gamma: 1.0,
            lut_size: 0,
            saturation: 1.0,
            vignette: 0.0,
            noise: 0.0,
            sharpen: 0.0,
        }
    }

    /// Xiaomi: warm, vivid look derived from libMiFilterSDK.so
    /// Filter 73 (Leica): LutSize=512, ExtraParam=1.4,1.0,0.2,1.0,0.25,0.4
    /// Shader: warm red/orange highlights, saturated colors
    pub fn xiaomi() -> Self {
        Self {
            matrix: [
                1.10, 0.03, -0.05,
                -0.02, 1.05, 0.01,
                -0.03, -0.02, 1.07
            ],
            gamma: 1.04,
            lut_size: 17,
            saturation: 1.12,
            vignette: 0.08,
            noise: 0.02,
            sharpen: 0.05,
        }
    }

    /// OPPO: cool, crisp (Hasselblad/Zeiss-inspired)
    /// Shader: blue/cyan highlights, crisp contrast
    pub fn oppo() -> Self {
        Self {
            matrix: [
                1.03, -0.01, -0.04,
                0.00, 1.07, -0.02,
                -0.04, -0.01, 1.05
            ],
            gamma: 1.02,
            lut_size: 17,
            saturation: 1.08,
            vignette: 0.05,
            noise: 0.01,
            sharpen: 0.08,
        }
    }

    /// Vivo: portrait-soft, warm skin tones (Zeiss-inspired)
    /// Shader: soft warm highlights, gentle contrast
    pub fn vivo() -> Self {
        Self {
            matrix: [
                1.07, 0.01, -0.02,
                0.01, 1.03, -0.03,
                -0.02, -0.04, 1.06
            ],
            gamma: 1.0,
            lut_size: 17,
            saturation: 1.05,
            vignette: 0.06,
            noise: 0.015,
            sharpen: 0.03,
        }
    }
}

/// Effect parameters passed as float[] to CandySDK.processBitmap
/// Maps to the uniform parameters in the shader code.
#[derive(Clone, Copy, Debug)]
pub struct EffectParams {
    pub saturation: f32,
    pub vignette: f32,
    pub noise: f32,
    pub sharpen: f32,
}

impl EffectParams {
    pub fn from_style(style: &StyleMatrix) -> [f32; 4] {
        [style.saturation, style.vignette, style.noise, style.sharpen]
    }
}
