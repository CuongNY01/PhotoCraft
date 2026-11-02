import cv2
import numpy as np
from PIL import Image, ImageEnhance
import io

def blend_images(original: np.ndarray, processed: np.ndarray, intensity: float) -> np.ndarray:
    """Blends processed image with original based on intensity (0.0 to 1.0)."""
    intensity = max(0.0, min(1.0, float(intensity)))
    if intensity <= 0.0:
        return original
    if intensity >= 1.0:
        return processed
    return cv2.addWeighted(processed, intensity, original, 1.0 - intensity, 0)

def apply_grayscale(img: np.ndarray, intensity: float = 1.0) -> np.ndarray:
    """Convert to grayscale (B&W) while keeping 3 channels."""
    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
    bgr_gray = cv2.cvtColor(gray, cv2.COLOR_GRAY2BGR)
    return blend_images(img, bgr_gray, intensity)

def apply_sepia(img: np.ndarray, intensity: float = 1.0) -> np.ndarray:
    """Apply classic warm sepia tone using color transform matrix."""
    # Standard Sepia matrix for BGR
    # R' = 0.393 R + 0.769 G + 0.189 B
    # G' = 0.349 R + 0.686 G + 0.168 B
    # B' = 0.272 R + 0.534 G + 0.131 B
    # In BGR order:
    sepia_matrix = np.array([
        [0.131, 0.534, 0.272],
        [0.168, 0.686, 0.349],
        [0.189, 0.769, 0.393]
    ], dtype=np.float32)
    
    sepia = cv2.transform(img, sepia_matrix)
    sepia = np.clip(sepia, 0, 255).astype(np.uint8)
    return blend_images(img, sepia, intensity)

def apply_vivid_hdr(img: np.ndarray, intensity: float = 1.0) -> np.ndarray:
    """Simulate vivid HDR: adaptive contrast (CLAHE on L-channel) + saturation boost."""
    # Convert BGR to LAB
    lab = cv2.cvtColor(img, cv2.COLOR_BGR2LAB)
    l, a, b = cv2.split(lab)
    
    # Apply CLAHE to L channel
    clahe = cv2.createCLAHE(clipLimit=2.5, tileGridSize=(8, 8))
    l_clahe = clahe.apply(l)
    
    lab_enhanced = cv2.merge([l_clahe, a, b])
    bgr_clahe = cv2.cvtColor(lab_enhanced, cv2.COLOR_LAB2BGR)
    
    # Boost saturation in HSV
    hsv = cv2.cvtColor(bgr_clahe, cv2.COLOR_BGR2HSV).astype(np.float32)
    h, s, v = cv2.split(hsv)
    s = s * 1.35
    s = np.clip(s, 0, 255)
    hsv_boosted = cv2.merge([h, s, v]).astype(np.uint8)
    hdr = cv2.cvtColor(hsv_boosted, cv2.COLOR_HSV2BGR)
    
    return blend_images(img, hdr, intensity)

def apply_vintage(img: np.ndarray, intensity: float = 1.0) -> np.ndarray:
    """Warm vintage / retro film filter with subtle vignette and warm highlights."""
    # Split channels (BGR)
    b, g, r = cv2.split(img.astype(np.float32))
    
    # Warm curves: boost Red, slightly drop Blue
    r_curve = np.clip(r * 1.15 + 10, 0, 255)
    g_curve = np.clip(g * 1.05 + 5, 0, 255)
    b_curve = np.clip(b * 0.85, 0, 255)
    vintage_bgr = cv2.merge([b_curve, g_curve, r_curve]).astype(np.uint8)
    
    # Add subtle vignette
    rows, cols = img.shape[:2]
    kernel_x = cv2.getGaussianKernel(cols, cols / 1.6)
    kernel_y = cv2.getGaussianKernel(rows, rows / 1.6)
    kernel = kernel_y * kernel_x.T
    mask = kernel / kernel.max()
    mask = np.clip(mask * 1.25, 0, 1)
    
    vignette = (vintage_bgr.astype(np.float32) * mask[:, :, np.newaxis]).astype(np.uint8)
    return blend_images(img, vignette, intensity)

def apply_cool(img: np.ndarray, intensity: float = 1.0) -> np.ndarray:
    """Cool / Cold Winter filter: boost blue tones, reduce warmth, crisp tone."""
    b, g, r = cv2.split(img.astype(np.float32))
    b_curve = np.clip(b * 1.20 + 15, 0, 255)
    g_curve = np.clip(g * 1.02, 0, 255)
    r_curve = np.clip(r * 0.85 - 5, 0, 255)
    cool_bgr = cv2.merge([b_curve, g_curve, r_curve]).astype(np.uint8)
    return blend_images(img, cool_bgr, intensity)

def apply_pencil(img: np.ndarray, intensity: float = 1.0) -> np.ndarray:
    """Artistic pencil sketch filter using OpenCV pencilSketch."""
    dst_gray, dst_color = cv2.pencilSketch(img, sigma_s=50, sigma_r=0.07, shade_factor=0.04)
    dst_bgr = cv2.cvtColor(dst_gray, cv2.COLOR_GRAY2BGR)
    return blend_images(img, dst_bgr, intensity)

def apply_emboss(img: np.ndarray, intensity: float = 1.0) -> np.ndarray:
    """Emboss 3D relief texture using directional convolution kernel."""
    kernel = np.array([
        [-2, -1,  0],
        [-1,  1,  1],
        [ 0,  1,  2]
    ], dtype=np.float32)
    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
    embossed = cv2.filter2D(gray, -1, kernel) + 128
    embossed = np.clip(embossed, 0, 255).astype(np.uint8)
    embossed_bgr = cv2.cvtColor(embossed, cv2.COLOR_GRAY2BGR)
    return blend_images(img, embossed_bgr, intensity)

def apply_invert(img: np.ndarray, intensity: float = 1.0) -> np.ndarray:
    """Invert colors / Negative film."""
    inverted = cv2.bitwise_not(img)
    return blend_images(img, inverted, intensity)

FILTER_REGISTRY = {
    "original": lambda img, intensity: img,
    "grayscale": apply_grayscale,
    "sepia": apply_sepia,
    "vivid_hdr": apply_vivid_hdr,
    "vintage": apply_vintage,
    "cool": apply_cool,
    "pencil": apply_pencil,
    "emboss": apply_emboss,
    "invert": apply_invert,
}

def apply_filter(img: np.ndarray, filter_type: str, intensity: float = 1.0) -> np.ndarray:
    filter_key = filter_type.strip().lower()
    handler = FILTER_REGISTRY.get(filter_key)
    if not handler:
        # Fallback to key matching
        for k in FILTER_REGISTRY:
            if k in filter_key or filter_key in k:
                handler = FILTER_REGISTRY[k]
                break
    if not handler:
        return img
    return handler(img, intensity)
