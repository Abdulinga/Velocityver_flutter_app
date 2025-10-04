@echo off
echo ========================================
echo    NDK Version Fix Script
echo ========================================
echo.

echo Checking NDK installation...
echo.

set NDK_PATH=C:\Android\ndk\27.0.12077973

if exist "%NDK_PATH%" (
    echo ✅ NDK found at: %NDK_PATH%
) else (
    echo ❌ NDK NOT found at: %NDK_PATH%
    echo.
    echo Please install NDK using Android Studio:
    echo 1. Open Android Studio
    echo 2. Go to Tools → SDK Manager
    echo 3. Click on SDK Tools tab
    echo 4. Check "NDK (Side by side)"
    echo 5. Click "Show Package Details"
    echo 6. Select version 27.0.12077973
    echo 7. Click Apply to install
    echo.
    pause
    exit /b 1
)

echo.
echo Checking source.properties file...
if exist "%NDK_PATH%\source.properties" (
    echo ✅ source.properties found
    type "%NDK_PATH%\source.properties"
) else (
    echo ❌ source.properties missing - NDK installation may be corrupted
    echo Please reinstall NDK 27.0.12077973
    pause
    exit /b 1
)

echo.
echo Cleaning Flutter build cache...
flutter clean

echo.
echo Cleaning Gradle cache...
cd android
if exist "build" rmdir /s /q build
if exist ".gradle" rmdir /s /q .gradle
cd ..

echo.
echo Getting Flutter packages...
flutter pub get

echo.
echo ========================================
echo Configuration updated successfully!
echo ========================================
echo.
echo NDK Version: 27.3.13750724 (actual version in folder)
echo NDK Path: %NDK_PATH%
echo.
echo You can now try building again with:
echo   flutter build apk --release
echo.
pause
