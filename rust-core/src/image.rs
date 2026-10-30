//! Per-pixel image processing pipeline: color matrix -> LUT -> gamma.

use crate::color::{apply_matrix, ColorMatrix};
use crate::lut::sample_lut;
use crate::tone::apply_gamma;

/// Minimal RGBA8 image view used internally by the core.
pub struct ImageBuffer {
    width: u32,
    height: u32,
    pixels: Vec<u8>, // RGBA8, row-major
}

impl ImageBuffer {
    pub fn from_rgba(width: usize, height: usize, bytes: &[u8]) -> Option<Self> {
        let needed = width * height * 4;
        if bytes.len() < needed {
            return None;
        }
        Some(Self {
            width: width as u32,
            height: height as u32,
            pixels: bytes[..needed].to_vec(),
        })
    }

    pub fn from_rgba_mut(width: usize, height: usize, bytes: &mut [u8]) -> Option<Self> {
        let needed = width * height * 4;
        if bytes.len() < needed {
            return None;
        }
        Some(Self {
            width: width as u32,
            height: height as u32,
            pixels: bytes[..needed].to_vec(),
        })
    }

    pub fn width(&self) -> u32 {
        self.width
    }
    pub fn height(&self) -> u32 {
        self.height
    }

    pub fn pixels(&self) -> &[u8] {
        &self.pixels
    }

    pub fn pixel(&self, x: u32, y: u32) -> [u8; 4] {
        let i = ((y * self.width + x) * 4) as usize;
        [
            self.pixels[i],
            self.pixels[i + 1],
            self.pixels[i + 2],
            self.pixels[i + 3],
        ]
    }

    pub fn set_pixel(&mut self, x: u32, y: u32, rgba: [u8; 4]) {
        let i = ((y * self.width + x) * 4) as usize;
        self.pixels[i] = rgba[0];
        self.pixels[i + 1] = rgba[1];
        self.pixels[i + 2] = rgba[2];
        self.pixels[i + 3] = rgba[3];
    }
}

/// Process a whole frame in place.
pub fn process_in_place(
    img: &mut ImageBuffer,
    matrix: &ColorMatrix,
    gamma: f32,
    lut: &[[f32; 3]; 4913],
) {
    let w = img.width();
    let h = img.height();
    for y in 0..h {
        for x in 0..w {
            let p = img.pixel(x, y);
            let r = p[0] as f32;
            let g = p[1] as f32;
            let b = p[2] as f32;

            // 1. 3x3 color matrix.
            let (mr, mg, mb) = apply_matrix(matrix, r, g, b);

            // 2. 3D LUT offset (sampled at normalized input color).
            let (lr, lg, lb) = sample_lut(lut, r / 255.0, g / 255.0, b / 255.0);

            // 3. Combine matrix output with LUT offset.
            let (cr, cg, cb) = (mr + lr, mg + lg, mb + lb);

            // 4. Gamma tone curve.
            let fr = apply_gamma(cr, gamma);
            let fg = apply_gamma(cg, gamma);
            let fb = apply_gamma(cb, gamma);

            img.set_pixel(x, y, [fr as u8, fg as u8, fb as u8, p[3]]);
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::color::NATURAL;
    use crate::lut::lut_for;
    use crate::tone::gamma_for;
    use crate::CameraStyle;

    fn make_pixel(r: u8, g: u8, b: u8, a: u8) -> [u8; 4] {
        [r, g, b, a]
    }

    #[test]
    fn natural_passthrough_leaves_pixels_unchanged() {
        let mut pixels = vec![10, 20, 30, 255, 200, 150, 100, 255];
        let mut img = ImageBuffer::from_rgba_mut(2, 1, &mut pixels).unwrap();
        process_in_place(
            &mut img,
            &NATURAL,
            gamma_for(CameraStyle::Natural),
            lut_for(CameraStyle::Natural),
        );
        assert_eq!(img.pixel(0, 0), make_pixel(10, 20, 30, 255));
        assert_eq!(img.pixel(1, 0), make_pixel(200, 150, 100, 255));
    }

    #[test]
    fn alpha_channel_is_preserved() {
        let mut pixels = vec![100, 100, 100, 128];
        let mut img = ImageBuffer::from_rgba_mut(1, 1, &mut pixels).unwrap();
        process_in_place(
            &mut img,
            &NATURAL,
            gamma_for(CameraStyle::Natural),
            lut_for(CameraStyle::Natural),
        );
        assert_eq!(img.pixel(0, 0)[3], 128);
    }

    #[test]
    fn from_rgba_rejects_too_small_buffer() {
        let too_small = [0u8; 3];
        assert!(ImageBuffer::from_rgba(1, 1, &too_small).is_none());
    }

    #[test]
    fn from_rgba_mut_rejects_too_small_buffer() {
        let mut too_small = [0u8; 3];
        assert!(ImageBuffer::from_rgba_mut(1, 1, &mut too_small).is_none());
    }
}
