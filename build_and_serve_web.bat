@echo off
echo ================================================
echo  Taal Trek - Build Web and Serve Locally
echo ================================================
echo.

cd /d "%~dp0"

echo [1/3] Building Flutter web app (release)...
flutter build web --release
if errorlevel 1 (
    echo.
    echo ERROR: Flutter build failed. Make sure you're running
    echo this from the Android Studio terminal where Flutter works.
    pause
    exit /b 1
)

echo.
echo [2/3] Build complete!
echo.
echo [3/3] Starting local server on http://localhost:8080
echo       Open that URL in Chrome on any device on your network.
echo       Press Ctrl+C to stop.
echo.

node serve_local.js 8080
