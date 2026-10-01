@echo off
setlocal enabledelayedexpansion
title Insta360 Studio Mod Launcher ^& Control Panel
cd /d "%~dp0"

:MENU
cls
echo ========================================================================
echo               INSTA360 STUDIO MOD LAUNCHER ^& CONTROL PANEL
echo ========================================================================
echo.

:: Check LUT Server Status
powershell -NoProfile -Command "$ErrorActionPreference='SilentlyContinue'; try { $r = Invoke-RestMethod -Uri 'http://127.0.0.1:8999/ping' -TimeoutSec 1; if ($r.status -eq 'ok') { exit 0 } } catch {}; exit 1"
if %errorlevel% equ 0 (
    echo   LUT Server Status:  [ ACTIVE - Port 8999 ] (Green)
) else (
    echo   LUT Server Status:  [ STOPPED ]
)

echo.
echo   ------------------------------------------------------------------
echo   [1]  LAUNCH Insta360 Studio  (Auto-starts LUT Server ^& opens app)
echo   ------------------------------------------------------------------
echo   [2]  Start / Restart LUT Background Server
echo   [3]  Stop LUT Background Server
echo   [4]  Apply All Mods ^& Patches (2.4x Export, In-App Grid UI)
echo   [5]  Restore Stock Binaries (Uninstall All Mods)
echo   [6]  Toggle Denoise Bypass (2.4x Fast Export vs Stock Smoothing)
echo   [7]  Open Custom LUTs Folder (Drag-and-drop .cube files)
echo   [8]  Open Standalone Floating LUT Switcher Window
echo   [0]  Exit
echo   ------------------------------------------------------------------
echo.
set /p opt="Select an option [0-8] (Default 1): "
if "%opt%"=="" set opt=1

if "%opt%"=="1" goto LAUNCH_APP
if "%opt%"=="2" goto START_SERVER
if "%opt%"=="3" goto STOP_SERVER
if "%opt%"=="4" goto APPLY_PATCHES
if "%opt%"=="5" goto RESTORE_STOCK
if "%opt%"=="6" goto TOGGLE_DENOISE
if "%opt%"=="7" goto OPEN_LUTS
if "%opt%"=="8" goto LAUNCH_PICKER
if "%opt%"=="0" exit /b
goto MENU

:LAUNCH_APP
echo.
echo [*] Checking LUT Background Server...
powershell -NoProfile -Command "$ErrorActionPreference='SilentlyContinue'; try { $r = Invoke-RestMethod -Uri 'http://127.0.0.1:8999/ping' -TimeoutSec 1; if ($r.status -eq 'ok') { exit 0 } } catch {}; exit 1"
if %errorlevel% neq 0 (
    echo [*] Starting LUT Server in background...
    powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process pythonw.exe -ArgumentList '\"%~dp0lut_service.py\"' -WorkingDirectory '%~dp0'"
    timeout /t 1 /nobreak >nul
)
echo [OK] LUT Server is active.

echo [*] Launching Insta360 Studio...
start "" "C:\Program Files\Insta360 Studio\Insta360 Studio.exe"
echo [OK] Insta360 Studio launched successfully!
timeout /t 2 /nobreak >nul
goto MENU

:START_SERVER
echo.
echo [*] Stopping any existing server...
powershell -NoProfile -Command "Get-CimInstance Win32_Process | Where-Object { $_.CommandLine -like '*lut_service.py*' } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force }" >nul 2>&1
echo [*] Starting LUT Server...
powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process pythonw.exe -ArgumentList '\"%~dp0lut_service.py\"' -WorkingDirectory '%~dp0'"
timeout /t 2 /nobreak >nul
echo [OK] Server started.
pause
goto MENU

:STOP_SERVER
echo.
echo [*] Stopping LUT Server...
powershell -NoProfile -Command "Get-CimInstance Win32_Process | Where-Object { $_.CommandLine -like '*lut_service.py*' } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force }" >nul 2>&1
echo [OK] Server stopped.
pause
goto MENU

:APPLY_PATCHES
echo.
echo [*] Running Mod Suite Installer...
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Install-Insta360Mod.ps1"
pause
goto MENU

:RESTORE_STOCK
echo.
echo [*] Restoring stock binaries...
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Install-Insta360Mod.ps1" -Uninstall
pause
goto MENU

:TOGGLE_DENOISE
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0ToggleDenoise.ps1"
goto MENU

:OPEN_LUTS
start "" "%~dp0Custom_LUTs"
goto MENU

:LAUNCH_PICKER
start "" pythonw.exe "%~dp0Insta360_LUT_Picker.pyw"
goto MENU
