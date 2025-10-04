@echo off
echo ========================================
echo    NDK Version Checker
echo ========================================
echo.

set NDK_PATH=C:\Android\ndk\27.0.12077973

echo Checking NDK at: %NDK_PATH%
echo.

if exist "%NDK_PATH%\source.properties" (
    echo ✅ Found source.properties file
    echo.
    echo Contents:
    type "%NDK_PATH%\source.properties"
    echo.
    
    echo Extracting version...
    for /f "tokens=2 delims==" %%a in ('findstr "Pkg.Revision" "%NDK_PATH%\source.properties"') do (
        echo Actual NDK Version: %%a
    )
) else (
    echo ❌ source.properties file not found
    echo This indicates the NDK installation may be corrupted
)

echo.
echo ========================================
echo Current Configuration:
echo ========================================
echo.
echo build.gradle.kts: ndkVersion = "27.3.13750724"
echo gradle.properties: android.ndkVersion=27.3.13750724
echo local.properties: ndk.dir=C:\\Android\\ndk\\27.0.12077973
echo.

echo If the versions don't match, the build will fail.
echo Make sure all configuration files use the same version
echo as shown in the source.properties file above.
echo.
pause
