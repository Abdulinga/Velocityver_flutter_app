@echo off
echo ========================================
echo    Database Reset Script
echo ========================================
echo.

echo This will reset the app database and create fresh default users.
echo.
echo Default Login Credentials:
echo ========================================
echo Super Admin:
echo   Username: superadmin
echo   Password: admin123
echo.
echo Admin:
echo   Username: admin
echo   Password: admin123
echo.
echo Lecturer:
echo   Username: lecturer
echo   Password: lecturer123
echo.
echo Student:
echo   Username: student
echo   Password: student123
echo ========================================
echo.

set /p confirm="Continue with database reset? (y/N): "
if /i not "%confirm%"=="y" (
    echo Operation cancelled.
    pause
    exit /b 0
)

echo.
echo Stopping any running Flutter processes...
taskkill /f /im flutter.exe >nul 2>&1
taskkill /f /im dart.exe >nul 2>&1

echo.
echo Cleaning Flutter build cache...
flutter clean

echo.
echo Removing app data (this will reset the database)...
adb shell pm clear com.example.velocityver >nul 2>&1

echo.
echo Rebuilding and installing app...
flutter build apk --debug
flutter install

echo.
echo ========================================
echo Database Reset Complete!
echo ========================================
echo.
echo You can now login with any of the credentials shown above.
echo The app will create a fresh database with default users.
echo.
pause
