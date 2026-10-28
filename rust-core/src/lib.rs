//! camera_core - Rust processing core for iPhone camera app
//!
//! Provides C ABI functions called from Swift:
//!   - apply_lut_3d: 3D LUT color grading (17^3 / 33^3)
//!   - apply_color_matrix: 3x3 color correction matrix
//!   - apply_tone_curve: gamma / tone mapping
//!   - apply_saturation: RGB saturation adjustment
//!   - apply_vignette: radial vignette darkening
//!   - apply_noise: film grain noise
//!   - blend_watermark: alpha-blend watermark onto pixel buffer
//!   - process_photo: combined pipeline (matrix + LUT + tone + effects + watermark)
//!   - fill_lut_for_style: generate LUT data for a given brand style
//!   - fill_effect_params: get effect parameters for a given brand style
//!
//! Pixel format: RGBA8, row-major, premultiplied alpha optional.
//! All buffers are owned by the caller (Swift); Rust only reads/writes via raw pointers.
//!
//! Derived from reverse engineering:
//!   - Xiaomi libMiFilterSDK.so (CandySDK): JNI setLutBitmap, setWatermark, processBitmap
//!   - vivo Camera 13.5.8.0: fragment_lookup_table_512.glsl (512^3 LUT shader)
//!   - Shader: glUniformMatrix3fv (color matrix), glTexImage3D (3D LUT)
//!   - Shader: vignette, noise, saturation effects

#![allow(clippy::cast_possible_truncation)]
#![allow(clippy::cast_sign_loss)]

use std::slice;
use std::io::Write;

mod lut_data;

// ---------------------------------------------------------------------------
// Logging for iOS - writes to stderr which iOS captures
// ---------------------------------------------------------------------------

/// Log a message to stderr for iOS crash logs
#[allow(dead_code)]
fn rust_log(level: &str, tag: &str, message: &str) {
    let timestamp = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map(|d| d.as_secs_f64())
        .unwrap_or(0.0);
    
    let log_line = format!("[{:.3}] [{}][{}] {}\n", timestamp, level, tag, message);
    
    // Write to stderr - iOS captures this in crash logs
    let _ = std::io::stderr().write_all(log_line.as_bytes());
    let _ = std::io::stderr().flush();
}

/// Log an error
#[allow(dead_code)]
fn rust_log_error(tag: &str, message: &str) {
    rust_log("ERROR", tag, message);
}

/// Log a warning
#[allow(dead_code)]
fn rust_log_warn(tag: &str, message: &str) {
    rust_log("WARN", tag, message);
}

/// Log info
#[allow(dead_code)]
fn rust_log_info(tag: &str, message: &str) {
    rust_log("INFO", tag, message);
}

// ---------------------------------------------------------------------------
// 3D LUT interpolation (trilinear)
// ---------------------------------------------------------------------------

/// Apply a 3D LUT to an RGBA8 buffer in place.
/// `lut_data` is `size^3 * 3` floats (R,G,B per node), in [0,1].
/// `size` is typically 17 or 33.
/// `row_bytes` must be >= width * 4. Only `width * 4` bytes per row are processed;
/// any padding bytes at the end of each row are left untouched.
#[no_mangle]
pub extern "C" fn apply_lut_3d(
    pixels: *mut u8,
    width: i32,
    height: i32,
    row_bytes: i32,
    lut_data: *const f32,
    lut_size: i32,
) -> i32 {
    if pixels.is_null() || lut_data.is_null() {
        return -1;
    }
    if width <= 0 || height <= 0 || row_bytes <= 0 {
        return -2;
    }
    if lut_size < 2 {
        return -3;
    }
    // row_bytes must be >= width * 4 (RGBA)
    if row_bytes < width * 4 {
        return -4;
    }

    let size = lut_size as usize;
    let inv_size_minus_one = 1.0f32 / ((size - 1) as f32);
    let lut = unsafe { slice::from_raw_parts(lut_data, size * size * size * 3) };
    let bytes_per_row = width as usize * 4;

    unsafe {
        let rows = slice::from_raw_parts_mut(pixels, height as usize * row_bytes as usize);
        for y in 0..height as usize {
            let row = rows.get_mut(y * row_bytes as usize..(y + 1) * row_bytes as usize);
            let Some(row) = row else { continue };
            for x in 0..width as usize {
                let base = x * 4;
                if base + 3 >= row.len() {
                    break;
                }
                let r = row[base] as f32 / 255.0;
                let g = row[base + 1] as f32 / 255.0;
                let b = row[base + 2] as f32 / 255.0;

                let (nr, ng, nb) = trilinear_lut(lut, size, r, g, b, inv_size_minus_one);

                row[base] = (nr.clamp(0.0, 1.0) * 255.0) as u8;
                row[base + 1] = (ng.clamp(0.0, 1.0) * 255.0) as u8;
                row[base + 2] = (nb.clamp(0.0, 1.0) * 255.0) as u8;
                // alpha (base+3) untouched
            }
        }
    }
    0
}

fn trilinear_lut(
    lut: &[f32],
    size: usize,
    r: f32,
    g: f32,
    b: f32,
    inv: f32,
) -> (f32, f32, f32) {
    let r_f = r * inv;
    let g_f = g * inv;
    let b_f = b * inv;

    let r0 = r_f.floor() as usize;
    let g0 = g_f.floor() as usize;
    let b0 = b_f.floor() as usize;
    let r1 = (r0 + 1).min(size - 1);
    let g1 = (g0 + 1).min(size - 1);
    let b1 = (b0 + 1).min(size - 1);

    let fr = r_f - r0 as f32;
    let fg = g_f - g0 as f32;
    let fb = b_f - b0 as f32;

    let idx = |r: usize, g: usize, b: usize| (r * size * size + g * size + b) * 3;

    let lerp = |a: f32, b: f32, t: f32| a + (b - a) * t;

    let mut out = [0.0f32; 3];
    for ch in 0..3 {
        let c000 = lut[idx(r0, g0, b0) + ch];
        let c100 = lut[idx(r1, g0, b0) + ch];
        let c010 = lut[idx(r0, g1, b0) + ch];
        let c001 = lut[idx(r0, g0, b1) + ch];
        let c110 = lut[idx(r1, g1, b0) + ch];
        let c101 = lut[idx(r1, g0, b1) + ch];
        let c011 = lut[idx(r0, g1, b1) + ch];
        let c111 = lut[idx(r1, g1, b1) + ch];

        let c00 = lerp(c000, c100, fr);
        let c01 = lerp(c001, c101, fr);
        let c10 = lerp(c010, c110, fr);
        let c11 = lerp(c011, c111, fr);
        out[ch] = lerp(lerp(c00, c10, fg), lerp(c01, c11, fg), fb);
    }

    (out[0], out[1], out[2])
}

// ---------------------------------------------------------------------------
// 3x3 Color Correction Matrix
// ---------------------------------------------------------------------------

/// Apply a 3x3 color matrix to RGB channels.
/// `matrix` is 9 floats in row-major order.
/// `row_bytes` must be >= width * 4. Only width*4 bytes per row are processed.
#[no_mangle]
pub extern "C" fn apply_color_matrix(
    pixels: *mut u8,
    width: i32,
    height: i32,
    row_bytes: i32,
    matrix: *const f32,
) -> i32 {
    if pixels.is_null() || matrix.is_null() {
        return -1;
    }
    if width <= 0 || height <= 0 || row_bytes <= 0 {
        return -2;
    }
    if row_bytes < width * 4 {
        return -4;
    }

    let m = unsafe { slice::from_raw_parts(matrix, 9) };
    let bytes_per_row = width as usize * 4;

    unsafe {
        let rows = slice::from_raw_parts_mut(pixels, height as usize * row_bytes as usize);
        for y in 0..height as usize {
            let row = rows.get_mut(y * row_bytes as usize..(y + 1) * row_bytes as usize);
            let Some(row) = row else { continue };
            for x in 0..width as usize {
                let base = x * 4;
                if base + 3 >= row.len() {
                    break;
                }
                let r = row[base] as f32 / 255.0;
                let g = row[base + 1] as f32 / 255.0;
                let b = row[base + 2] as f32 / 255.0;

                let nr = r * m[0] + g * m[1] + b * m[2];
                let ng = r * m[3] + g * m[4] + b * m[5];
                let nb = r * m[6] + g * m[7] + b * m[8];

                row[base] = (nr.clamp(0.0, 1.0) * 255.0) as u8;
                row[base + 1] = (ng.clamp(0.0, 1.0) * 255.0) as u8;
                row[base + 2] = (nb.clamp(0.0, 1.0) * 255.0) as u8;
            }
        }
    }
    0
}

// ---------------------------------------------------------------------------
// 512^3 LUT from 2D texture (vivo style)
// ---------------------------------------------------------------------------
//
// Implements vivo's fragment_lookup_table_512.glsl:
//   - 512^3 LUT encoded as 512x512 2D texture
//   - Blue channel (0-63) selects LUT slice
//   - R/G channels select position within slice
//   - Trilinear interpolation between adjacent slices

/// Apply a 512^3 3D LUT encoded as a 512x512 2D texture (vivo style).
/// `lut_texture` is 512x512 RGBA8 pixels encoding the 3D LUT.
/// `strength` = 0.0 (no effect) to 1.0 (full LUT applied).
/// `row_bytes` must be >= width * 4.
#[no_mangle]
pub extern "C" fn apply_lut_512(
    pixels: *mut u8,
    width: i32,
    height: i32,
    row_bytes: i32,
    lut_texture: *const u8,
    lut_width: i32,
    lut_height: i32,
    strength: f32,
) -> i32 {
    if pixels.is_null() || lut_texture.is_null() {
        return -1;
    }
    if width <= 0 || height <= 0 || row_bytes <= 0 {
        return -2;
    }
    if lut_width != 512 || lut_height != 512 {
        return -3;
    }
    if row_bytes < width * 4 {
        return -4;
    }

    let lut = unsafe { slice::from_raw_parts(lut_texture, 512 * 512 * 4) };

    unsafe {
        let rows = slice::from_raw_parts_mut(pixels, height as usize * row_bytes as usize);
        for y in 0..height as usize {
            let row = rows.get_mut(y * row_bytes as usize..(y + 1) * row_bytes as usize);
            let Some(row) = row else { continue };
            for x in 0..width as usize {
                let base = x * 4;
                if base + 3 >= row.len() {
                    break;
                }
                let r = row[base] as f32 / 255.0;
                let g = row[base + 1] as f32 / 255.0;
                let b = row[base + 2] as f32 / 255.0;

                let blue_val = b * 63.0;

                // Slice indices (quad1 = floor, quad2 = ceil)
                let slice1 = blue_val.floor() as i32;
                let slice2 = (blue_val.ceil() as i32).min(63);
                let frac = blue_val - blue_val.floor();

                // Helper to sample the 2D LUT texture
                let sample_lut = |slice: i32, r: f32, g: f32| -> [f32; 3] {
                    // vivo shader: texPos.x = quad.x * 0.125 + 0.5/512 + (0.125 - 1/512) * r
                    //              texPos.y = quad.y * 0.125 + 0.5/512 + (0.125 - 1/512) * g
                    let cell_size = 0.125;
                    let half_texel = 0.5 / 512.0;
                    let scale = cell_size - 1.0 / 512.0;

                    let quad_x = slice % 8;
                    let quad_y = slice / 8;

                    let tx = quad_x as f32 * cell_size + half_texel + scale * r;
                    let ty = quad_y as f32 * cell_size + half_texel + scale * g;

                    let px = (tx * 511.0).round() as usize;
                    let py = (ty * 511.0).round() as usize;

                    let idx = (py * 512 + px) * 4;
                    if idx + 2 < lut.len() {
                        [
                            lut[idx] as f32 / 255.0,
                            lut[idx + 1] as f32 / 255.0,
                            lut[idx + 2] as f32 / 255.0,
                        ]
                    } else {
                        [r, g, b]
                    }
                };

                let c1 = sample_lut(slice1, r, g);
                let c2 = sample_lut(slice2, r, g);

                let nr = c1[0] + (c2[0] - c1[0]) * frac;
                let ng = c1[1] + (c2[1] - c1[1]) * frac;
                let nb = c1[2] + (c2[2] - c1[2]) * frac;

                // Mix with original based on strength
                row[base] = ((r + (nr - r) * strength).clamp(0.0, 1.0) * 255.0) as u8;
                row[base + 1] = ((g + (ng - g) * strength).clamp(0.0, 1.0) * 255.0) as u8;
                row[base + 2] = ((b + (nb - b) * strength).clamp(0.0, 1.0) * 255.0) as u8;
            }
        }
    }
    0
}

// ---------------------------------------------------------------------------
// Saturation adjustment
// ---------------------------------------------------------------------------

/// Adjust RGB saturation around luminance.
/// `saturation` = 1.0 is unchanged, >1.0 more saturated, <1.0 less saturated.
/// `row_bytes` must be >= width * 4.
#[no_mangle]
pub extern "C" fn apply_saturation(
    pixels: *mut u8,
    width: i32,
    height: i32,
    row_bytes: i32,
    saturation: f32,
) -> i32 {
    if pixels.is_null() {
        return -1;
    }
    if width <= 0 || height <= 0 || row_bytes <= 0 {
        return -2;
    }
    if row_bytes < width * 4 {
        return -4;
    }

    unsafe {
        let rows = slice::from_raw_parts_mut(pixels, height as usize * row_bytes as usize);
        for y in 0..height as usize {
            let row = rows.get_mut(y * row_bytes as usize..(y + 1) * row_bytes as usize);
            let Some(row) = row else { continue };
            for x in 0..width as usize {
                let base = x * 4;
                if base + 3 >= row.len() {
                    break;
                }
                let r = row[base] as f32 / 255.0;
                let g = row[base + 1] as f32 / 255.0;
                let b = row[base + 2] as f32 / 255.0;

                let lum = 0.2126 * r + 0.7152 * g + 0.0722 * b;
                let nr = lum + (r - lum) * saturation;
                let ng = lum + (g - lum) * saturation;
                let nb = lum + (b - lum) * saturation;

                row[base] = (nr.clamp(0.0, 1.0) * 255.0) as u8;
                row[base + 1] = (ng.clamp(0.0, 1.0) * 255.0) as u8;
                row[base + 2] = (nb.clamp(0.0, 1.0) * 255.0) as u8;
            }
        }
    }
    0
}

// ---------------------------------------------------------------------------
// Tone curve / gamma
// ---------------------------------------------------------------------------

/// Apply a simple gamma curve to RGB channels.
/// `gamma` > 0. Typical: 1.0 (none), 0.8 (brighten), 1.2 (darken).
/// `row_bytes` must be >= width * 4.
#[no_mangle]
pub extern "C" fn apply_tone_curve(
    pixels: *mut u8,
    width: i32,
    height: i32,
    row_bytes: i32,
    gamma: f32,
) -> i32 {
    if pixels.is_null() {
        return -1;
    }
    if width <= 0 || height <= 0 || row_bytes <= 0 {
        return -2;
    }
    if gamma <= 0.0 {
        return -3;
    }
    if row_bytes < width * 4 {
        return -4;
    }

    let inv_gamma = 1.0 / gamma;

    unsafe {
        let rows = slice::from_raw_parts_mut(pixels, height as usize * row_bytes as usize);
        for y in 0..height as usize {
            let row = rows.get_mut(y * row_bytes as usize..(y + 1) * row_bytes as usize);
            let Some(row) = row else { continue };
            for x in 0..width as usize {
                let base = x * 4;
                if base + 3 >= row.len() {
                    break;
                }
                let r = row[base] as f32 / 255.0;
                let g = row[base + 1] as f32 / 255.0;
                let b = row[base + 2] as f32 / 255.0;

                row[base] = (r.powf(inv_gamma).clamp(0.0, 1.0) * 255.0) as u8;
                row[base + 1] = (g.powf(inv_gamma).clamp(0.0, 1.0) * 255.0) as u8;
                row[base + 2] = (b.powf(inv_gamma).clamp(0.0, 1.0) * 255.0) as u8;
            }
        }
    }
    0
}

// ---------------------------------------------------------------------------
// Vignette (radial darkening toward corners)
// ---------------------------------------------------------------------------

/// Apply radial vignette darkening.
/// `strength` = 0.0 is none, 1.0 is strong corner darkening.
/// `row_bytes` must be >= width * 4.
#[no_mangle]
pub extern "C" fn apply_vignette(
    pixels: *mut u8,
    width: i32,
    height: i32,
    row_bytes: i32,
    strength: f32,
) -> i32 {
    if pixels.is_null() {
        return -1;
    }
    if width <= 0 || height <= 0 || row_bytes <= 0 {
        return -2;
    }
    if row_bytes < width * 4 {
        return -4;
    }

    let cx = width as f32 / 2.0;
    let cy = height as f32 / 2.0;
    let max_dist = (cx * cx + cy * cy).sqrt();

    unsafe {
        let rows = slice::from_raw_parts_mut(pixels, height as usize * row_bytes as usize);
        for y in 0..height as usize {
            let row = rows.get_mut(y * row_bytes as usize..(y + 1) * row_bytes as usize);
            let Some(row) = row else { continue };
            for x in 0..width as usize {
                let base = x * 4;
                if base + 3 >= row.len() {
                    break;
                }
                let dx = x as f32 - cx;
                let dy = y as f32 - cy;
                let dist = (dx * dx + dy * dy).sqrt() / max_dist;
                let vignette_factor = 1.0 - strength * dist * dist;

                row[base] = ((row[base] as f32) * vignette_factor).clamp(0.0, 255.0) as u8;
                row[base + 1] = ((row[base + 1] as f32) * vignette_factor).clamp(0.0, 255.0) as u8;
                row[base + 2] = ((row[base + 2] as f32) * vignette_factor).clamp(0.0, 255.0) as u8;
            }
        }
    }
    0
}

// ---------------------------------------------------------------------------
// Film grain noise
// ---------------------------------------------------------------------------

/// Add pseudo-random film grain noise.
/// `strength` = 0.0 is none, 1.0 is strong noise.
/// `row_bytes` must be >= width * 4.
#[no_mangle]
pub extern "C" fn apply_noise(
    pixels: *mut u8,
    width: i32,
    height: i32,
    row_bytes: i32,
    strength: f32,
    seed: u32,
) -> i32 {
    if pixels.is_null() {
        return -1;
    }
    if width <= 0 || height <= 0 || row_bytes <= 0 {
        return -2;
    }
    if row_bytes < width * 4 {
        return -4;
    }

    // Simple xorshift32 PRNG
    let mut state: u32 = seed;

    unsafe {
        let rows = slice::from_raw_parts_mut(pixels, height as usize * row_bytes as usize);
        for y in 0..height as usize {
            let row = rows.get_mut(y * row_bytes as usize..(y + 1) * row_bytes as usize);
            let Some(row) = row else { continue };
            for x in 0..width as usize {
                let base = x * 4;
                if base + 3 >= row.len() {
                    break;
                }
                // xorshift32
                state ^= state << 13;
                state ^= state >> 17;
                state ^= state << 5;
                let noise = ((state % 256) as f32 / 255.0 - 0.5) * 2.0 * strength * 255.0;

                row[base] = (row[base] as f32 + noise).clamp(0.0, 255.0) as u8;
                row[base + 1] = (row[base + 1] as f32 + noise).clamp(0.0, 255.0) as u8;
                row[base + 2] = (row[base + 2] as f32 + noise).clamp(0.0, 255.0) as u8;
            }
        }
    }
    0
}

// ---------------------------------------------------------------------------
// Watermark blend
// ---------------------------------------------------------------------------

/// Alpha-blend a watermark RGBA8 buffer onto the main buffer at (x, y).
/// `wm_alpha` multiplies the watermark alpha (0.0 = invisible, 1.0 = full).
/// `row_bytes` must be >= width * 4.
#[no_mangle]
pub extern "C" fn blend_watermark(
    pixels: *mut u8,
    width: i32,
    height: i32,
    row_bytes: i32,
    wm_pixels: *const u8,
    wm_width: i32,
    wm_height: i32,
    wm_row_bytes: i32,
    offset_x: i32,
    offset_y: i32,
    wm_alpha: f32,
) -> i32 {
    if pixels.is_null() || wm_pixels.is_null() {
        return -1;
    }
    if width <= 0 || height <= 0 || row_bytes <= 0 {
        return -2;
    }
    if row_bytes < width * 4 {
        return -4;
    }
    if wm_width <= 0 || wm_height <= 0 || wm_row_bytes <= 0 {
        return -3;
    }

    let wm = unsafe { slice::from_raw_parts(wm_pixels, wm_height as usize * wm_row_bytes as usize) };

    let start_x = offset_x.max(0) as usize;
    let start_y = offset_y.max(0) as usize;
    let end_x = (offset_x + wm_width).min(width) as usize;
    let end_y = (offset_y + wm_height).min(height) as usize;

    if start_x >= end_x || start_y >= end_y {
        return 0;
    }

    unsafe {
        let main_rows = slice::from_raw_parts_mut(pixels, height as usize * row_bytes as usize);
        for y in start_y..end_y {
            let wm_y = y as i32 - offset_y;
            let wm_row = wm.get(wm_y as usize * wm_row_bytes as usize..(wm_y as usize + 1) * wm_row_bytes as usize);
            let Some(wm_row) = wm_row else { continue };

            let main_row = main_rows.get_mut(y * row_bytes as usize..(y + 1) * row_bytes as usize);
            let Some(main_row) = main_row else { continue };

            for x in start_x..end_x {
                let wm_x = x as i32 - offset_x;
                let wm_base = wm_x as usize * 4;
                if wm_base + 3 >= wm_row.len() {
                    break;
                }
                let base = x * 4;
                if base + 3 >= main_row.len() {
                    break;
                }

                let wm_a = wm_row[wm_base + 3] as f32 / 255.0 * wm_alpha;
                if wm_a <= 0.0 {
                    continue;
                }
                if wm_a >= 1.0 {
                    main_row[base] = wm_row[wm_base];
                    main_row[base + 1] = wm_row[wm_base + 1];
                    main_row[base + 2] = wm_row[wm_base + 2];
                    main_row[base + 3] = 255;
                    continue;
                }

                let inv_a = 1.0 - wm_a;
                main_row[base] = ((wm_row[wm_base] as f32 * wm_a) + (main_row[base] as f32 * inv_a)) as u8;
                main_row[base + 1] = ((wm_row[wm_base + 1] as f32 * wm_a) + (main_row[base + 1] as f32 * inv_a)) as u8;
                main_row[base + 2] = ((wm_row[wm_base + 2] as f32 * wm_a) + (main_row[base + 2] as f32 * inv_a)) as u8;
                main_row[base + 3] = 255;
            }
        }
    }
    0
}

// ---------------------------------------------------------------------------
// Combined pipeline (one-call convenience)
// ---------------------------------------------------------------------------

/// Process a full photo frame in one call:
///   1. Color matrix
///   2. 3D LUT (optional, pass null lut_data to skip)
///   3. Tone curve (gamma)
///   4. Saturation
///   5. Vignette
///   6. Noise
///   7. Watermark (optional, pass null wm_pixels to skip)
///
/// Returns 0 on success, negative on error.
#[no_mangle]
pub extern "C" fn process_photo(
    pixels: *mut u8,
    width: i32,
    height: i32,
    row_bytes: i32,
    // Color matrix (9 floats, row-major). Pass null to skip.
    matrix: *const f32,
    // 3D LUT data (size^3 * 3 floats). Pass null to skip.
    lut_data: *const f32,
    lut_size: i32,
    // Tone curve gamma. Pass 1.0 to skip.
    gamma: f32,
    // Saturation (1.0 = none)
    saturation: f32,
    // Vignette strength (0.0 = none)
    vignette: f32,
    // Noise strength (0.0 = none)
    noise: f32,
    // Noise seed
    noise_seed: u32,
    // Watermark RGBA8. Pass null to skip.
    wm_pixels: *const u8,
    wm_width: i32,
    wm_height: i32,
    wm_row_bytes: i32,
    wm_offset_x: i32,
    wm_offset_y: i32,
    wm_alpha: f32,
) -> i32 {
    if pixels.is_null() {
        return -1;
    }
    if width <= 0 || height <= 0 || row_bytes <= 0 {
        return -2;
    }

    // 1. Color matrix
    if !matrix.is_null() {
        let rc = apply_color_matrix(pixels, width, height, row_bytes, matrix);
        if rc != 0 {
            return rc;
        }
    }

    // 2. 3D LUT
    if !lut_data.is_null() && lut_size >= 2 {
        let rc = apply_lut_3d(pixels, width, height, row_bytes, lut_data, lut_size);
        if rc != 0 {
            return rc;
        }
    }

    // 3. Tone curve
    if gamma > 0.0 && gamma != 1.0 {
        let rc = apply_tone_curve(pixels, width, height, row_bytes, gamma);
        if rc != 0 {
            return rc;
        }
    }

    // 4. Saturation
    if saturation > 0.0 && saturation != 1.0 {
        let rc = apply_saturation(pixels, width, height, row_bytes, saturation);
        if rc != 0 {
            return rc;
        }
    }

    // 5. Vignette
    if vignette > 0.0 {
        let rc = apply_vignette(pixels, width, height, row_bytes, vignette);
        if rc != 0 {
            return rc;
        }
    }

    // 6. Noise
    if noise > 0.0 {
        let rc = apply_noise(pixels, width, height, row_bytes, noise, noise_seed);
        if rc != 0 {
            return rc;
        }
    }

    // 7. Watermark
    if !wm_pixels.is_null() && wm_width > 0 && wm_height > 0 {
        let rc = blend_watermark(
            pixels, width, height, row_bytes,
            wm_pixels, wm_width, wm_height, wm_row_bytes,
            wm_offset_x, wm_offset_y, wm_alpha,
        );
        if rc != 0 {
            return rc;
        }
    }

    0
}

// ---------------------------------------------------------------------------
// LUT generation for FFI
// ---------------------------------------------------------------------------

/// Fill a caller-provided buffer with LUT data for a given style.
/// `style_id`: 0=natural, 1=xiaomi, 2=oppo, 3=vivo
/// `output` must point to `size^3 * 3` f32 values.
/// Returns 0 on success, negative on error.
#[no_mangle]
pub extern "C" fn fill_lut_for_style(
    style_id: i32,
    size: i32,
    output: *mut f32,
    output_len: i32,
) -> i32 {
    if output.is_null() {
        return -1;
    }
    if size < 2 {
        return -2;
    }
    let needed = (size as usize).pow(3) * 3;
    if (output_len as usize) < needed {
        return -3;
    }

    let style = match style_id {
        0 => lut_data::StyleMatrix::natural(),
        1 => lut_data::StyleMatrix::xiaomi(),
        2 => lut_data::StyleMatrix::oppo(),
        3 => lut_data::StyleMatrix::vivo(),
        _ => return -4,
    };

    let size_usize = size as usize;

    unsafe {
        let out_slice = slice::from_raw_parts_mut(output, needed);
        let mut idx = 0;
        for r in 0..size_usize {
            let rf = r as f32 / (size_usize - 1) as f32;
            for g in 0..size_usize {
                let gf = g as f32 / (size_usize - 1) as f32;
                for b in 0..size_usize {
                    let bf = b as f32 / (size_usize - 1) as f32;

                    let nr = rf * style.matrix[0] + gf * style.matrix[1] + bf * style.matrix[2];
                    let ng = rf * style.matrix[3] + gf * style.matrix[4] + bf * style.matrix[5];
                    let nb = rf * style.matrix[6] + gf * style.matrix[7] + bf * style.matrix[8];

                    let inv_gamma = 1.0 / style.gamma;
                    out_slice[idx] = (nr.clamp(0.0, 1.0).powf(inv_gamma)).clamp(0.0, 1.0);
                    out_slice[idx + 1] = (ng.clamp(0.0, 1.0).powf(inv_gamma)).clamp(0.0, 1.0);
                    out_slice[idx + 2] = (nb.clamp(0.0, 1.0).powf(inv_gamma)).clamp(0.0, 1.0);
                    idx += 3;
                }
            }
        }
    }

    0
}

/// Fill effect parameters for a given style.
/// `style_id`: 0=natural, 1=xiaomi, 2=oppo, 3=vivo
/// `output` must point to at least 4 f32 values: [saturation, vignette, noise, sharpen]
/// Returns 0 on success, negative on error.
#[no_mangle]
pub extern "C" fn fill_effect_params_for_style(
    style_id: i32,
    output: *mut f32,
    output_len: i32,
) -> i32 {
    if output.is_null() {
        return -1;
    }
    if (output_len as usize) < 4 {
        return -2;
    }

    let style = match style_id {
        0 => lut_data::StyleMatrix::natural(),
        1 => lut_data::StyleMatrix::xiaomi(),
        2 => lut_data::StyleMatrix::oppo(),
        3 => lut_data::StyleMatrix::vivo(),
        _ => return -3,
    };

    let params = lut_data::EffectParams::from_style(&style);

    unsafe {
        let out_slice = slice::from_raw_parts_mut(output, 4);
        out_slice[0] = params[0]; // saturation
        out_slice[1] = params[1]; // vignette
        out_slice[2] = params[2]; // noise
        out_slice[3] = params[3]; // sharpen
    }

    0
}
