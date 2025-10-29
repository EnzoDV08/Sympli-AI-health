@echo off
echo =====================================================
echo   Launching Sympli Emulator + Flutter...
echo =====================================================
cd "C:\Users\enzod\Documents\GitHub\firebase-exercise-fork\Sympli-AI-health"

:: Restart adb so the emulator always connects
adb kill-server >nul
adb start-server >nul

:: Check if emulator is already running
for /f "tokens=*" %%a in ('adb devices ^| findstr /R /C:"emulator-"') do set EMURUNNING=1

if defined EMURUNNING (
    echo ✅ Emulator already running. Skipping launch...
) else (
    echo 🚀 Starting Pixel_9_Pro_XL...
    start "" "%LOCALAPPDATA%\Android\Sdk\emulator\emulator.exe" -avd Pixel_9_Pro_XL
    echo 🔄 Waiting for emulator to boot...
    for /L %%i in (1,1,12) do (
        timeout /t 10 >nul
        adb devices | find "emulator-" >nul && goto ready
        echo   ...still waiting (%%i0s elapsed)
    )
)

:ready
echo ✅ Emulator is ready!
echo Running Flutter app...
flutter run
