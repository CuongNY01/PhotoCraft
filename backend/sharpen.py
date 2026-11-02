import cv2
import numpy as np

def sharpen_kernel_3x3(img: np.ndarray, strength: float = 1.0) -> np.ndarray:
    """
    Sharpen using 3x3 Convolution Kernel:
    [  0,   -w,    0 ]
    [ -w, 1+4w,   -w ]
    [  0,   -w,    0 ]
    where w is adjusted by strength.
    """
    strength = max(0.0, min(5.0, float(strength)))
    if strength <= 0.01:
        return img
    
    w = 0.5 * strength
    kernel = np.array([
        [ 0, -w,  0],
        [-w, 1.0 + 4.0 * w, -w],
        [ 0, -w,  0]
    ], dtype=np.float32)
    
    sharpened = cv2.filter2D(img, -1, kernel)
    return np.clip(sharpened, 0, 255).astype(np.uint8)

def sharpen_unsharp_mask(img: np.ndarray, strength: float = 1.0, radius: float = 1.5) -> np.ndarray:
    """
    Unsharp Masking (USM):
    1. Smooth image using Gaussian blur.
    2. Subtract blurred image from original to isolate high-frequency details (mask).
    3. Add scaled mask back into original image: output = original + strength * (original - blurred).
    """
    strength = max(0.0, min(5.0, float(strength)))
    if strength <= 0.01:
        return img
    
    # Gaussian blur for high frequency separation
    gaussian = cv2.GaussianBlur(img, (0, 0), sigmaX=radius, sigmaY=radius)
    # unsharp mask = img + strength * (img - gaussian)
    # Equivalently: cv2.addWeighted(img, 1.0 + strength, gaussian, -strength, 0)
    sharpened = cv2.addWeighted(img, 1.0 + strength, gaussian, -strength, 0)
    return np.clip(sharpened, 0, 255).astype(np.uint8)

def sharpen_high_boost(img: np.ndarray, strength: float = 1.0) -> np.ndarray:
    """
    High-Boost Filter:
    Amplifies high frequencies with an amplification factor A > 1.
    High-Boost = A * Original - Low-Pass = (A - 1) * Original + High-Pass.
    """
    strength = max(0.0, min(5.0, float(strength)))
    if strength <= 0.01:
        return img
    
    A = 1.0 + 0.8 * strength
    blurred = cv2.blur(img, (3, 3))
    high_boost = cv2.addWeighted(img, A, blurred, -(A - 1.0), 0)
    return np.clip(high_boost, 0, 255).astype(np.uint8)

def sharpen_clahe(img: np.ndarray, strength: float = 1.0) -> np.ndarray:
    """
    Contrast Limited Adaptive Histogram Equalization (CLAHE):
    Operates on the Luminance (L) channel of the LAB color space to dramatically
    enhance local contrast and structural details without altering colors.
    """
    strength = max(0.0, min(5.0, float(strength)))
    if strength <= 0.01:
        return img
    
    lab = cv2.cvtColor(img, cv2.COLOR_BGR2LAB)
    l, a, b = cv2.split(lab)
    
    clip_limit = 1.0 + 3.0 * strength
    clahe = cv2.createCLAHE(clipLimit=clip_limit, tileGridSize=(8, 8))
    l_enhanced = clahe.apply(l)
    
    lab_enhanced = cv2.merge([l_enhanced, a, b])
    result = cv2.cvtColor(lab_enhanced, cv2.COLOR_LAB2BGR)
    return result

SHARPEN_REGISTRY = {
    "kernel_3x3": sharpen_kernel_3x3,
    "kernel": sharpen_kernel_3x3,
    "unsharp_mask": sharpen_unsharp_mask,
    "usm": sharpen_unsharp_mask,
    "high_boost": sharpen_high_boost,
    "clahe": sharpen_clahe,
}

def apply_sharpen(img: np.ndarray, method: str, strength: float = 1.0) -> np.ndarray:
    method_key = method.strip().lower().replace(" ", "_")
    handler = SHARPEN_REGISTRY.get(method_key)
    if not handler:
        for k in SHARPEN_REGISTRY:
            if k in method_key or method_key in k:
                handler = SHARPEN_REGISTRY[k]
                break
    if not handler:
        return img
    return handler(img, strength)
