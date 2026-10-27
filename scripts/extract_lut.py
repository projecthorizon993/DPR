#!/usr/bin/env python3
"""
extract_lut.py - Derive 3D LUT from sample photos (OEM vs iPhone)

Usage:
    python extract_lut.py --iphone sample_iphone.jpg --oem sample_xiaomi.jpg --output lut_xiaomi_17.cube --size 17

This script:
1. Loads an iPhone photo and the same scene shot with OEM camera (Xiaomi/vivo/OPPO)
2. Computes per-pixel color mapping
3. Generates a 3D LUT (.cube format) that approximates the OEM look
4. Outputs a C header or Rust array embeddable in camera_core

Requirements:
    pip install numpy pillow scipy colour-science
"""

import argparse
import json
import sys
import numpy as np
from PIL import Image

try:
    from scipy.interpolate import RegularGridInterpolator
except ImportError:
    print("Installing dependencies: pip install numpy pillow scipy")
    sys.exit(1)


def load_image(path):
    """Load image as float32 RGB in [0,1]."""
    img = Image.open(path).convert("RGB")
    arr = np.asarray(img, dtype=np.float32) / 255.0
    return arr


def downsample_lut(lut_512, target_size=17):
    """
    Downsample a 512^3 LUT to target_size^3 by trilinear sampling.
    lut_512: (512, 512, 512, 3) float array in [0,1]
    """
    size = target_size
    # Create target grid coordinates in [0,1]
    grid = np.linspace(0, 1, size)
    # For each output node, sample the input LUT
    # Build coordinate arrays
    coords = np.array(np.meshgrid(grid, grid, grid, indexing='ij'))
    coords = np.stack(coords, axis=-1)  # (size, size, size, 3)
    # Scale to input LUT coords [0, 511]
    input_coords = coords * (512 - 1)
    
    # Use RegularGridInterpolator for trilinear sampling
    input_grid = np.linspace(0, 1, 512)
    interpolator = RegularGridInterpolator(
        (input_grid, input_grid, input_grid),
        lut_512,
        bounds_error=False,
        fill_value=None
    )
    
    # Flatten for interpolation
    flat_coords = input_coords.reshape(-1, 3)
    flat_result = interpolator(flat_coords)
    result = flat_result.reshape(size, size, size, 3)
    return result


def lut_to_cube(lut, size):
    """
    Convert numpy LUT (size, size, size, 3) to .cube format string.
    """
    lines = []
    lines.append("LUT_3D_SIZE {}".format(size))
    lines.append("DOMAIN_MIN 0.0 0.0 0.0")
    lines.append("DOMAIN_MAX 1.0 1.0 1.0")
    
    # .cube format: R varies slowest, B varies fastest
    # Actually standard .cube: for each R, for each G, for each B: output R G B
    for r in range(size):
        for g in range(size):
            for b in range(size):
                out = lut[r, g, b]
                lines.append("{:.6f} {:.6f} {:.6f}".format(out[0], out[1], out[2]))
    
    return "\n".join(lines)


def lut_to_rust_array(lut, size, name="lut_data"):
    """
    Convert numpy LUT to Rust static array string.
    """
    flat = lut.reshape(-1, 3)
    lines = []
    lines.append("pub static {}: [f32; {}] = [".format(name, flat.shape[0] * 3))
    for i in range(0, flat.shape[0], 8):
        chunk = flat[i:i+8]
        vals = []
        for v in chunk:
            vals.extend(["{:.6f}".format(x) for x in v])
        lines.append("    " + ", ".join(vals) + ",")
    lines.append("];")
    return "\n".join(lines)


def derive_lut_from_pairs(iphone_pixels, oem_pixels, size=17):
    """
    Given paired pixel arrays (iphone, oem) both (N, 3) in [0,1],
    derive a 3D LUT that maps iphone -> oem colors.
    
    Approach:
    1. Create a regular grid in RGB space (the LUT nodes)
    2. For each node, find the nearest iPhone pixels and compute average OEM color
    3. Interpolate across the grid
    """
    from scipy.spatial import cKDTree
    
    # Build KD-tree on iPhone pixels for fast nearest-neighbor
    tree = cKDTree(iphone_pixels)
    
    # Create output LUT grid
    grid = np.linspace(0, 1, size)
    lut = np.zeros((size, size, size, 3), dtype=np.float32)
    
    for ri, r in enumerate(grid):
        for gi, g in enumerate(grid):
            for bi, b in enumerate(grid):
                query_point = np.array([r, g, b])
                # Find k nearest iPhone pixels
                k = min(50, len(iphone_pixels))
                dists, indices = tree.query(query_point, k=k)
                
                if np.isscalar(indices):
                    indices = [indices]
                
                # Average the corresponding OEM colors
                oem_colors = oem_pixels[indices]
                lut[ri, gi, bi] = np.mean(oem_colors, axis=0)
    
    return lut


def main():
    parser = argparse.ArgumentParser(description="Derive 3D LUT from OEM vs iPhone sample photos")
    parser.add_argument("--iphone", required=True, help="Path to iPhone reference photo")
    parser.add_argument("--oem", required=True, help="Path to OEM camera photo (same scene)")
    parser.add_argument("--output", required=True, help="Output .cube file path")
    parser.add_argument("--size", type=int, default=17, help="LUT grid size (default: 17)")
    parser.add_argument("--rust-output", help="Also output Rust array file")
    parser.add_argument("--rust-name", default="lut_data", help="Rust array name")
    parser.add_argument("--max-pixels", type=int, default=100000, help="Max pixels to sample per image")
    
    args = parser.parse_args()
    
    print("Loading images...")
    iphone = load_image(args.iphone)
    oem = load_image(args.oem)
    
    if iphone.shape != oem.shape:
        print("Resizing OEM to match iPhone dimensions...")
        oem_img = Image.fromarray((oem * 255).astype(np.uint8))
        oem_img = oem_img.resize((iphone.shape[1], iphone.shape[0]), Image.LANCZOS)
        oem = np.asarray(oem_img, dtype=np.float32) / 255.0
    
    # Flatten to pixel arrays
    iphone_flat = iphone.reshape(-1, 3)
    oem_flat = oem.reshape(-1, 3)
    
    # Subsample for speed
    if len(iphone_flat) > args.max_pixels:
        idx = np.random.choice(len(iphone_flat), args.max_pixels, replace=False)
        iphone_flat = iphone_flat[idx]
        oem_flat = oem_flat[idx]
    
    print(f"Using {len(iphone_flat)} pixel pairs for LUT derivation...")
    
    print(f"Deriving {args.size}^{args.size}^{args.size} LUT...")
    lut = derive_lut_from_pairs(iphone_flat, oem_flat, args.size)
    
    # Write .cube file
    cube_data = lut_to_cube(lut, args.size)
    with open(args.output, "w") as f:
        f.write(cube_data)
    print(f"LUT written to {args.output}")
    
    # Optionally write Rust array
    if args.rust_output:
        rust_data = lut_to_rust_array(lut, args.size, args.rust_name)
        with open(args.rust_output, "w") as f:
            f.write(rust_data)
        print(f"Rust array written to {args.rust_output}")
    
    print("\nNext steps:")
    print(f"  1. Add {args.output} to your iOS app bundle")
    print(f"  2. Parse the .cube file in Swift to get Float array")
    print(f"  3. Pass to Rust camera_core::apply_lut_3d()")


if __name__ == "__main__":
    main()
