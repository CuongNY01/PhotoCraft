import os
import sys
from pathlib import Path

# Add current directory to sys.path so sibling imports work seamlessly
sys.path.insert(0, str(Path(__file__).resolve().parent))

from fastapi import FastAPI, UploadFile, File, Form, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import Response, JSONResponse
import cv2
import numpy as np
import logging
from typing import Optional
from filters import apply_filter, FILTER_REGISTRY
from sharpen import apply_sharpen, SHARPEN_REGISTRY

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("photocraft_api")

app = FastAPI(
    title="PhotoCraft Image Processing API",
    description="Python OpenCV/PIL backend for mobile photo editing, color filtering and sharpening",
    version="1.0.0"
)

# Enable CORS for Flutter Mobile, Web, and desktop
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

def decode_image(file_bytes: bytes) -> np.ndarray:
    nparr = np.frombuffer(file_bytes, np.uint8)
    img = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
    if img is None:
        raise HTTPException(status_code=400, detail="Could not decode image file")
    return img

def encode_image(img: np.ndarray, format: str = ".jpg") -> bytes:
    encode_params = [int(cv2.IMWRITE_JPEG_QUALITY), 92] if format.lower() in [".jpg", ".jpeg"] else []
    success, buffer = cv2.imencode(format, img, encode_params)
    if not success:
        raise HTTPException(status_code=500, detail="Failed to encode processed image")
    return buffer.tobytes()

@app.get("/")
def root():
    return {
        "status": "online",
        "app": "PhotoCraft Backend API",
        "version": "1.0.0",
        "docs": "/docs"
    }

@app.get("/api/health")
def health_check():
    return {
        "status": "healthy",
        "opencv_version": cv2.__version__,
        "supported_filters": list(FILTER_REGISTRY.keys()),
        "supported_sharpening": list(SHARPEN_REGISTRY.keys())
    }

@app.get("/api/info")
def get_info():
    return {
        "filters": [
            {"id": "original", "name": "Gốc", "description": "Ảnh gốc ban đầu"},
            {"id": "grayscale", "name": "Trắng đen", "description": "Chuyển ảnh thành đơn sắc trắng đen"},
            {"id": "sepia", "name": "Sepia", "description": "Tông màu nâu cổ điển phương Tây"},
            {"id": "vivid_hdr", "name": "vivi HDR", "description": "Tăng cường độ bão hòa, tương phản và chi tiết HDR"},
            {"id": "vintage", "name": "Màu 1 (Vintage)", "description": "Tông màu ấm áp phong cách retro film với viền mờ"},
            {"id": "cool", "name": "Màu 2 (Lạnh / Cool)", "description": "Tông màu xanh mát, trong trẻo, sắc nét"},
            {"id": "pencil", "name": "Tranh chì", "description": "Hiệu ứng phác thảo tranh chì nghệ thuật"},
            {"id": "emboss", "name": "Chạm nổi (Emboss)", "description": "Hiệu ứng bề mặt điêu khắc 3D"},
            {"id": "invert", "name": "Đảo màu", "description": "Hiệu ứng film âm bản"}
        ],
        "sharpening": [
            {"id": "kernel_3x3", "name": "Kernel 3x3", "description": "Bộ lọc tích chập không gian tăng cường cạnh chi tiết"},
            {"id": "unsharp_mask", "name": "Unsharp Mask (USM)", "description": "Làm nét cao cấp bằng Gaussian Mask"},
            {"id": "high_boost", "name": "High-Boost Filter", "description": "Khuếch đại thành phần tần số cao làm rõ ảnh mờ"},
            {"id": "clahe", "name": "CLAHE Contrast", "description": "Cân bằng biểu đồ độ sáng thích ứng nâng cao chi tiết"}
        ]
    }

@app.post("/api/filter")
async def filter_endpoint(
    file: UploadFile = File(...),
    filter_type: str = Form("grayscale"),
    intensity: float = Form(1.0)
):
    try:
        contents = await file.read()
        img = decode_image(contents)
        logger.info(f"Applying filter '{filter_type}' with intensity {intensity:.2f} on image size {img.shape}")
        
        result = apply_filter(img, filter_type=filter_type, intensity=intensity)
        output_bytes = encode_image(result, format=".jpg")
        
        return Response(
            content=output_bytes,
            media_type="image/jpeg",
            headers={
                "X-Filter-Applied": filter_type,
                "X-Intensity": str(intensity),
                "X-Image-Width": str(result.shape[1]),
                "X-Image-Height": str(result.shape[0])
            }
        )
    except HTTPException:
        raise
    except Exception as e:
        logger.exception("Error applying filter")
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/api/sharpen")
async def sharpen_endpoint(
    file: UploadFile = File(...),
    method: str = Form("unsharp_mask"),
    strength: float = Form(1.0)
):
    try:
        contents = await file.read()
        img = decode_image(contents)
        logger.info(f"Applying sharpening '{method}' with strength {strength:.2f} on image size {img.shape}")
        
        result = apply_sharpen(img, method=method, strength=strength)
        output_bytes = encode_image(result, format=".jpg")
        
        return Response(
            content=output_bytes,
            media_type="image/jpeg",
            headers={
                "X-Sharpen-Method": method,
                "X-Strength": str(strength),
                "X-Image-Width": str(result.shape[1]),
                "X-Image-Height": str(result.shape[0])
            }
        )
    except HTTPException:
        raise
    except Exception as e:
        logger.exception("Error applying sharpening")
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/api/process")
async def process_endpoint(
    file: UploadFile = File(...),
    filter_type: Optional[str] = Form(None),
    filter_intensity: Optional[float] = Form(1.0),
    sharpen_method: Optional[str] = Form(None),
    sharpen_strength: Optional[float] = Form(1.0)
):
    try:
        contents = await file.read()
        img = decode_image(contents)
        
        # 1. Apply filter if provided
        if filter_type and filter_type.lower() != "original" and filter_type.lower() != "none":
            logger.info(f"Pipeline: applying filter '{filter_type}'")
            img = apply_filter(img, filter_type=filter_type, intensity=filter_intensity or 1.0)
            
        # 2. Apply sharpen if provided
        if sharpen_method and sharpen_method.lower() != "none":
            logger.info(f"Pipeline: applying sharpening '{sharpen_method}'")
            img = apply_sharpen(img, method=sharpen_method, strength=sharpen_strength or 1.0)
            
        output_bytes = encode_image(img, format=".jpg")
        return Response(
            content=output_bytes,
            media_type="image/jpeg"
        )
    except HTTPException:
        raise
    except Exception as e:
        logger.exception("Error in pipeline process")
        raise HTTPException(status_code=500, detail=str(e))

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)
