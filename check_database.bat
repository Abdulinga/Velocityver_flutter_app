@echo off
echo ========================================
echo    Database Location Checker
echo ========================================
echo.

echo Checking for database files on connected Android device...
echo.

echo 1. Checking app data directory...
adb shell "ls -la /data/data/com.example.velocityver/databases/" 2>nul
if %errorlevel% equ 0 (
    echo ✅ App databases directory found
) else (
    echo ❌ App databases directory not found
    echo    This could mean:
    echo    - App is not installed
    echo    - App hasn't been launched yet
    echo    - Database creation failed
)

echo.
echo 2. Checking for specific database file...
adb shell "ls -la /data/data/com.example.velocityver/databases/velocityver.db" 2>nul
if %errorlevel% equ 0 (
    echo ✅ Database file found: velocityver.db
) else (
    echo ❌ Database file not found: velocityver.db
)

echo.
echo 3. Checking app installation...
adb shell "pm list packages | grep com.example.velocityver" 2>nul
if %errorlevel% equ 0 (
    echo ✅ App is installed
) else (
    echo ❌ App is not installed
    echo    Run: flutter install
)

echo.
echo 4. Getting app logs (last 50 lines)...
echo Looking for database initialization messages...
adb logcat -t 50 | findstr /i "database\|velocityver\|sqlite"

echo.
echo ========================================
echo Manual Database Creation Steps:
echo ========================================
echo.
echo If database is not found, try:
echo 1. Uninstall app: adb uninstall com.example.velocityver
echo 2. Rebuild: flutter clean && flutter build apk --debug
echo 3. Install: flutter install
echo 4. Launch app and check logs: adb logcat | findstr VelocityVer
echo.
pause
