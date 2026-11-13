@echo off
setlocal
echo ==========================================================
echo        PhotoCraft - Xem truc tiep tren Trinh duyet Chrome
echo ==========================================================

REM Kiem tra xem Python Backend API (port 8000) da chay chua
netstat -ano | findstr :8000 | findstr LISTENING >nul 2>&1
if %errorlevel% neq 0 (
    echo [1/2] Dang tu dong khoi dong Python Backend API tai http://127.0.0.1:8000 ...
    start "PhotoCraft Python Backend (Port 8000)" cmd /k "cd /d ""%~dp0"" && python -m uvicorn backend.main:app --host 0.0.0.0 --port 8000 --reload"
    timeout /t 2 >nul
) else (
    echo [1/2] Python Backend API da san sang tren cong 8000.
)

echo [2/2] Dang khoi chay PhotoCraft tren Trinh duyet Chrome...
cd /d "%~dp0\mobile_app"
flutter run -d chrome
pause
