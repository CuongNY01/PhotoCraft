@echo off
echo ==========================================================
echo        PhotoCraft - Khoi dong Python Backend API
echo        (OpenCV, PIL, FastAPI, Uvicorn)
echo ==========================================================
cd /d "%~dp0"
python -m uvicorn backend.main:app --host 0.0.0.0 --port 8000 --reload
pause
