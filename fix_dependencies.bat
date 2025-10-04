@echo off
echo ========================================
echo    Flutter Dependencies Fix
echo ========================================
echo.

echo Step 1: Cleaning Flutter cache...
flutter clean

echo.
echo Step 2: Cleaning pub cache...
flutter pub cache clean

echo.
echo Step 3: Removing pubspec.lock...
if exist "pubspec.lock" del pubspec.lock

echo.
echo Step 4: Cleaning Android build cache...
cd android
if exist "build" rmdir /s /q build
if exist ".gradle" rmdir /s /q .gradle
cd ..

echo.
echo Step 5: Getting updated dependencies...
flutter pub get

echo.
echo Step 6: Upgrading dependencies...
flutter pub upgrade

echo.
echo ========================================
echo Dependencies Updated Successfully!
echo ========================================
echo.
echo Updated packages:
echo - file_picker: ^8.1.2 (was ^6.1.1)
echo - sqflite: ^2.4.1 (was ^2.2.0)
echo - connectivity_plus: ^6.1.0 (was ^4.0.0)
echo - And other dependencies...
echo.
echo You can now try building again with:
echo   flutter build apk --release
echo.
pause
