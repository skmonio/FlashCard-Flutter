@echo off
echo ================================================
echo  Taal Trek - Build Debug APK
echo ================================================
echo.

cd /d "%~dp0"

echo Building APK...
flutter build apk --debug
if errorlevel 1 (
    echo.
    echo ERROR: Flutter build failed. Run this from the Android Studio terminal.
    pause
    exit /b 1
)

echo.
echo ================================================
echo  APK ready at:
echo  build\app\outputs\flutter-apk\app-debug.apk
echo ================================================
echo.
echo To install on a connected device, run:
echo   flutter install
echo.
pause
