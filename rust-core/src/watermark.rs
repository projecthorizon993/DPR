//! Alpha-blended watermark compositing.

use crate::image::ImageBuffer;

/// Blend an RGBA8 watermark image onto an RGBA8 frame at an integer offset.
///
/// `opacity` is applied to the watermark alpha (0.0 = invisible, 1.0 = full watermark alpha).
pub fn blend_into(
    frame: &mut ImageBuffer,
    watermark: &ImageBuffer,
    offset_x: i32,
    offset_y: i32,
    opacity: f32,
) {
    let opacity = opacity.clamp(0.0, 1.0);
    let fw = frame.width() as i32;
    let fh = frame.height() as i32;
    let ww = watermark.width() as i32;
    let wh = watermark.height() as i32;

    // Clamp the watermark draw region to the frame bounds.
    let start_x = offset_x.max(0);
    let start_y = offset_y.max(0);
    let end_x = (offset_x + ww).min(fw);
    let end_y = (offset_y + wh).min(fh);

    if start_x >= end_x || start_y >= end_y {
        return;
    }

    for y in start_y..end_y {
        let wy = y - offset_y;
        for x in start_x..end_x {
            let wx = x - offset_x;

            let fp = frame.pixel(x as u32, y as u32);
            let wp = watermark.pixel(wx as u32, wy as u32);

            let a = (wp[3] as f32 / 255.0) * opacity;
            if a <= 0.0 {
                continue;
            }
            let ia = 1.0 - a;

            let r = (fp[0] as f32 * ia + wp[0] as f32 * a)
                .round()
                .clamp(0.0, 255.0) as u8;
            let g = (fp[1] as f32 * ia + wp[1] as f32 * a)
                .round()
                .clamp(0.0, 255.0) as u8;
            let b = (fp[2] as f32 * ia + wp[2] as f32 * a)
                .round()
                .clamp(0.0, 255.0) as u8;

            frame.set_pixel(x as u32, y as u32, [r, g, b, fp[3]]);
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::ImageBuffer;

    #[test]
    fn zero_opacity_leaves_frame_unchanged() {
        let mut frame_pixels = vec![100, 150, 200, 255, 50, 60, 70, 255];
        let mut frame = ImageBuffer::from_rgba_mut(2, 1, &mut frame_pixels).unwrap();
        let wm_pixels = vec![255, 0, 0, 255];
        let wm = ImageBuffer::from_rgba(1, 1, &wm_pixels).unwrap();
        blend_into(&mut frame, &wm, 0, 0, 0.0);
        assert_eq!(frame.pixel(0, 0), [100, 150, 200, 255]);
    }

    #[test]
    fn full_opacity_overwrites_destination() {
        let mut frame_pixels = vec![0, 0, 0, 255];
        let mut frame = ImageBuffer::from_rgba_mut(1, 1, &mut frame_pixels).unwrap();
        let wm_pixels = vec![255, 0, 0, 255];
        let wm = ImageBuffer::from_rgba(1, 1, &wm_pixels).unwrap();
        blend_into(&mut frame, &wm, 0, 0, 1.0);
        assert_eq!(frame.pixel(0, 0), [255, 0, 0, 255]);
    }

    #[test]
    fn half_opacity_blends() {
        let mut frame_pixels = vec![0, 0, 0, 255];
        let mut frame = ImageBuffer::from_rgba_mut(1, 1, &mut frame_pixels).unwrap();
        let wm_pixels = vec![255, 255, 255, 255];
        let wm = ImageBuffer::from_rgba(1, 1, &wm_pixels).unwrap();
        blend_into(&mut frame, &wm, 0, 0, 0.5);
        // Black blended halfway with white = 127/128.
        assert_eq!(frame.pixel(0, 0)[0], 128);
    }

    #[test]
    fn watermark_outside_frame_is_noop() {
        let mut frame_pixels = vec![100, 100, 100, 255];
        let mut frame = ImageBuffer::from_rgba_mut(1, 1, &mut frame_pixels).unwrap();
        let wm_pixels = vec![255, 0, 0, 255];
        let wm = ImageBuffer::from_rgba(1, 1, &wm_pixels).unwrap();
        blend_into(&mut frame, &wm, 10, 10, 1.0);
        assert_eq!(frame.pixel(0, 0), [100, 100, 100, 255]);
    }

    #[test]
    fn zero_alpha_watermark_is_noop() {
        let mut frame_pixels = vec![100, 100, 100, 255];
        let mut frame = ImageBuffer::from_rgba_mut(1, 1, &mut frame_pixels).unwrap();
        let wm_pixels = vec![255, 0, 0, 0]; // fully transparent
        let wm = ImageBuffer::from_rgba(1, 1, &wm_pixels).unwrap();
        blend_into(&mut frame, &wm, 0, 0, 1.0);
        assert_eq!(frame.pixel(0, 0), [100, 100, 100, 255]);
    }
}
