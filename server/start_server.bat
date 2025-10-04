@echo off
echo ========================================
echo    VelocityVer Server Startup
echo ========================================
echo.

REM Check if Python is installed
python --version >nul 2>&1
if errorlevel 1 (
    echo ERROR: Python is not installed or not in PATH
    echo Please install Python 3.7+ from https://python.org
    pause
    exit /b 1
)

echo Python found. Checking dependencies...

REM Install required packages if not present
pip install flask flask-cors werkzeug >nul 2>&1

echo.
echo Starting VelocityVer Server...
echo.
echo IMPORTANT: Make sure Windows Firewall allows Python/Flask
echo           or temporarily disable firewall for testing
echo.

REM Start the Flask server
python app.py

echo.
echo Server stopped. Press any key to exit...
pause >nul
