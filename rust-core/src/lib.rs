//! camera-core — from-scratch image-processing core for CameraApp.
//!
//! Exposes a small C ABI so Swift (AVFoundation) can push RGBA8 frames through
//! per-style processing: 3x3 color matrix, 3D LUT, gamma tone curve, and
//! alpha-blended watermark. Nothing here is copied from another project.

mod color;
mod image;
mod lut;
mod tone;
mod watermark;

use image::ImageBuffer;

/// Styles exposed to Swift. Kept in sync with the Swift `CameraStyle` enum.
#[repr(C)]
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum CameraStyle {
    Natural = 0,
    Xiaomi = 1,
    Oppo = 2,
    Vivo = 3,
}

/// A caller-owned RGBA8 frame. Swift allocates the byte buffer; we process in place.
#[repr(C)]
pub struct CameraFrame {
    pub width: u32,
    pub height: u32,
    pub bytes: *mut u8,
    pub byte_count: usize,
}

/// Result handed back to Swift.
#[repr(C)]
pub struct CameraResult {
    pub ok: bool,
    pub code: u32,
}

const CODE_OK: u32 = 0;
const CODE_NULL_POINTER: u32 = 1;
const CODE_BAD_DIMENSIONS: u32 = 2;
const CODE_BUFFER_TOO_SMALL: u32 = 3;

/// Process one RGBA8 frame in place with the given style.
///
/// # Safety
/// `frame` must be non-null. `frame.bytes` must point to `byte_count` initialized
/// bytes, and `byte_count` must be at least `width * height * 4`.
#[no_mangle]
pub extern "C" fn camera_process_frame(frame: *mut CameraFrame, style: CameraStyle) -> CameraResult {
    if frame.is_null() {
        return CameraResult { ok: false, code: CODE_NULL_POINTER };
    }

    let frame = unsafe { &mut *frame };
    if frame.width == 0 || frame.height == 0 || frame.bytes.is_null() {
        return CameraResult { ok: false, code: CODE_BAD_DIMENSIONS };
    }

    let expected = (frame.width as usize) * (frame.height as usize) * 4;
    if frame.byte_count < expected {
        return CameraResult { ok: false, code: CODE_BUFFER_TOO_SMALL };
    }

    let bytes = unsafe { std::slice::from_raw_parts_mut(frame.bytes, expected) };
    let mut img = match ImageBuffer::from_rgba_mut(frame.width as usize, frame.height as usize, bytes) {
        Some(img) => img,
        None => return CameraResult { ok: false, code: CODE_BAD_DIMENSIONS },
    };

    let matrix = color::matrix_for(style);
    let gamma = tone::gamma_for(style);
    let lut = lut::lut_for(style);

    image::process_in_place(&mut img, &matrix, gamma, &lut);

    CameraResult { ok: true, code: CODE_OK }
}

/// Blend an RGBA8 watermark onto an RGBA8 frame at an offset, with opacity.
///
/// # Safety
/// Both pointers must be non-null and each buffer must be at least
/// `width * height * 4` (frame) or `wm_width * wm_height * 4` (watermark).
#[no_mangle]
pub extern "C" fn camera_blend_watermark(
    frame: *mut u8,
    frame_width: u32,
    frame_height: u32,
    watermark: *const u8,
    wm_width: u32,
    wm_height: u32,
    offset_x: i32,
    offset_y: i32,
    opacity: f32,
) -> CameraResult {
    if frame.is_null() || watermark.is_null() {
        return CameraResult { ok: false, code: CODE_NULL_POINTER };
    }
    if frame_width == 0 || frame_height == 0 || wm_width == 0 || wm_height == 0 {
        return CameraResult { ok: false, code: CODE_BAD_DIMENSIONS };
    }

    let frame_bytes = (frame_width as usize) * (frame_height as usize) * 4;
    let wm_bytes = (wm_width as usize) * (wm_height as usize) * 4;

    let frame_slice = unsafe { std::slice::from_raw_parts_mut(frame, frame_bytes) };
    let wm_slice = unsafe { std::slice::from_raw_parts(watermark, wm_bytes) };

    let mut img = match ImageBuffer::from_rgba_mut(frame_width as usize, frame_height as usize, frame_slice) {
        Some(img) => img,
        None => return CameraResult { ok: false, code: CODE_BAD_DIMENSIONS },
    };
    let wm = match ImageBuffer::from_rgba(wm_width as usize, wm_height as usize, wm_slice) {
        Some(wm) => wm,
        None => return CameraResult { ok: false, code: CODE_BAD_DIMENSIONS },
    };

    watermark::blend_into(&mut img, &wm, offset_x, offset_y, opacity);

    CameraResult { ok: true, code: CODE_OK }
}
