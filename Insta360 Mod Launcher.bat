@echo off
setlocal enabledelayedexpansion
title Insta360 Studio Mod Launcher ^& Control Panel
cd /d "%~dp0"

:MENU
cls
echo ========================================================================
echo              INSTA360 STUDIO MOD LAUNCHER ^& CONTROL PANEL
echo ========================================================================
echo.

:: Detect LUT Background Server Status
set "SERVER_STATUS=[ STOPPED ]"
curl.exe -s --max-time 1 http://127.0.0.1:8999/ping | findstr "ok" >nul 2>&1
if !errorlevel! equ 0 (
    set "SERVER_STATUS=[ ACTIVE - Port 8999 ]"
)

:: Dynamic Rescan of Custom_LUTs folder
set "LUT_COUNT=0"
for /f %%A in ('powershell -NoProfile -Command "(Get-ChildItem -Path '%~dp0Custom_LUTs' -Filter '*.cube' -File -ErrorAction SilentlyContinue).Count"') do set "LUT_COUNT=%%A"

:: Detect Denoise Bypass Mod Status in studio_worker.dll
set "DENOISE_STATUS=[ UNKNOWN ]"
powershell -NoProfile -Command "$stream=[System.IO.File]::OpenRead('C:\Program Files\Insta360 Studio\studio_worker.dll'); $stream.Seek(0x31CE730,0)|Out-Null; $b=New-Object byte[] 6; $stream.Read($b,0,6)|Out-Null; $stream.Close(); $h=[BitConverter]::ToString($b) -replace '-',''; if($h -eq '31C0C3909090'){exit 10} elseif($h -eq '48895C241855'){exit 11} else{exit 12}" >nul 2>&1
set "PS_CODE=%errorlevel%"
if "%PS_CODE%"=="10" set "DENOISE_STATUS=[ ON - 2.4x Fast Export Active ]"
if "%PS_CODE%"=="11" set "DENOISE_STATUS=[ OFF - Stock Denoise Active ]"

:: Detect In-App LUT UI & EXE Patch Status
set "EXE_STATUS=[ UNKNOWN ]"
powershell -NoProfile -Command "$stream=[System.IO.File]::OpenRead('C:\Program Files\Insta360 Studio\Insta360 Studio.exe'); $stream.Seek(0x3011930,0)|Out-Null; $b=New-Object byte[] 5; $stream.Read($b,0,5)|Out-Null; $stream.Close(); $h=[BitConverter]::ToString($b) -replace '-',''; if($h -eq 'B001C39090'){exit 20} else{exit 21}" >nul 2>&1
set "EXE_CODE=%errorlevel%"
if "%EXE_CODE%"=="20" set "EXE_STATUS=[ INSTALLED - In-App UI + Sliders Unlocked ]"
if "%EXE_CODE%"=="21" set "EXE_STATUS=[ STOCK - Original Unmodified EXE ]"

echo   -- STATUS DASHBOARD ----------------------------------------------
echo      LUT Server Status   : %SERVER_STATUS%
echo      LUT Library Rescan  : [ !LUT_COUNT! .cube LUTs loaded from Custom_LUTs ]
echo      Fast Export Mod     : %DENOISE_STATUS%
echo      Studio EXE Patches  : %EXE_STATUS%
echo      Default LUT State   : [ OFF by default / Stock Rec.709 fallback ]
echo      Motion ND Default   : [ OFF by default / Clean UI toggle export ]
echo   ------------------------------------------------------------------
echo.
echo   ==================================================================
echo   == SEGMENT 1: LAUNCH OPTIONS ==
echo   ==================================================================
echo     [1] Launch App (Full Mods: Auto-starts server, ensures safe stock LUT)
echo     [2] Launch App As-Is   (Launches Studio immediately with current state)
echo.
echo   ==================================================================
echo   == SEGMENT 2: FEATURE TOGGLES (ON / OFF) ==
echo   ==================================================================
echo     [3] Toggle 2.4x Fast Export Mod       (Bypass AI denoise in DLL)
echo     [4] Toggle In-App LUT UI ^& EXE Patch (Install / Remove EXE mods)
echo     [5] Toggle LUT Background Server     (Start / Stop port 8999 service)
echo     [6] Safe Reset Active LUT to Stock   (Restore Stock Rec.709 in i_log)
echo.
echo   ==================================================================
echo   == SEGMENT 3: FULL RESET ==
echo   ==================================================================
echo     [7] Reset All to Stock (Full Factory Uninstall: Restore factory binaries)
echo.
echo   ==================================================================
echo   == SEGMENT 4: TOOLS ^& SHORTCUTS ==
echo   ==================================================================
echo     [8] Open Custom LUTs Folder (Add / Remove .cube files)
echo     [9] Launch Standalone Floating LUT Picker Window
echo     [0] Exit
echo   ==================================================================
echo.
set /p opt="Select an option [0-9] (Default 1): "
if "%opt%"=="" set opt=1

if "%opt%"=="1" goto LAUNCH_FULL
if "%opt%"=="2" goto LAUNCH_AS_IS
if "%opt%"=="3" goto TOGGLE_DENOISE
if "%opt%"=="4" goto TOGGLE_EXE_PATCH
if "%opt%"=="5" goto TOGGLE_SERVER
if "%opt%"=="6" goto RESET_LUT
if "%opt%"=="7" goto RESET_ALL
if "%opt%"=="8" goto OPEN_LUTS
if "%opt%"=="9" goto LAUNCH_PICKER
if "%opt%"=="0" exit /b
goto MENU

:: ---------------------------------------------------------------------
:: 1. LAUNCH OPTIONS
:: ---------------------------------------------------------------------
:LAUNCH_FULL
echo.
echo [*] Rescanning Custom_LUTs... Found !LUT_COUNT! .cube LUT files.
echo [*] Checking LUT Background Server...
curl.exe -s --max-time 1 http://127.0.0.1:8999/ping | findstr "ok" >nul 2>&1
if !errorlevel! neq 0 (
    echo [*] Starting background LUT service...
    start "" pythonw.exe "%~dp0lut_service.py"
    timeout /t 1 /nobreak >nul
)
:: Ensure safe stock LUT is active to prevent crashes from broken LUTs
echo [*] Setting safe stock fallback LUT...
curl.exe -s --max-time 1 http://127.0.0.1:8999/reset >nul 2>&1

:: Ensure modded files are deployed
if "%PS_CODE%" neq "10" (
    echo [*] Deploying modded studio_worker DLL (2.4x Fast Export)...
    copy /y "%~dp0studio_worker_nodenoise.dll" "C:\Program Files\Insta360 Studio\studio_worker.dll" >nul 2>&1
)
if "%EXE_CODE%" neq "20" (
    echo [*] Deploying modded Studio EXE (Universal LUT + Motion ND Off)...
    copy /y "%~dp0Insta360 Studio_lutmod.exe" "C:\Program Files\Insta360 Studio\Insta360 Studio.exe" >nul 2>&1
)
copy /y "%~dp0L.qml" "C:\Users\Public\L.qml" >nul 2>&1

echo [*] Launching Insta360 Studio (Full Mods)...
start "" "C:\Program Files\Insta360 Studio\Insta360 Studio.exe"
echo [OK] Insta360 Studio launched!
timeout /t 2 /nobreak >nul
goto MENU

:LAUNCH_AS_IS
echo.
echo [*] Launching Insta360 Studio as-is (no changes applied)...
start "" "C:\Program Files\Insta360 Studio\Insta360 Studio.exe"
echo [OK] Launched!
timeout /t 2 /nobreak >nul
goto MENU

:: ---------------------------------------------------------------------
:: 2. FEATURE TOGGLES
:: ---------------------------------------------------------------------
:TOGGLE_DENOISE
echo.
echo [*] Toggling 2.4x Fast Export Denoise Bypass...
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0ToggleDenoise.ps1"
goto MENU

:TOGGLE_EXE_PATCH
echo.
if "%EXE_CODE%"=="20" (
    echo [*] Removing Studio EXE patches (Restoring stock EXE)...
    taskkill /F /IM "Insta360 Studio.exe" >nul 2>&1
    copy /y "%~dp0Insta360 Studio_stock.exe" "C:\Program Files\Insta360 Studio\Insta360 Studio.exe" >nul
    echo [OK] Stock Studio EXE restored.
) else (
    echo [*] Applying Studio EXE patches (In-App UI + Unlocked Sliders)...
    taskkill /F /IM "Insta360 Studio.exe" >nul 2>&1
    copy /y "%~dp0Insta360 Studio_lutmod.exe" "C:\Program Files\Insta360 Studio\Insta360 Studio.exe" >nul
    copy /y "%~dp0L.qml" "C:\Users\Public\L.qml" >nul
    echo [OK] Studio EXE patches applied!
)
pause
goto MENU

:TOGGLE_SERVER
echo.
curl.exe -s --max-time 1 http://127.0.0.1:8999/ping | findstr "ok" >nul 2>&1
if !errorlevel! equ 0 (
    echo [*] Stopping LUT Background Server...
    powershell -NoProfile -Command "Get-CimInstance Win32_Process | Where-Object { `$_.CommandLine -like '*lut_service.py*' } | ForEach-Object { Stop-Process -Id `$_.ProcessId -Force }" >nul 2>&1
    echo [OK] Server stopped.
) else (
    echo [*] Rescanning Custom_LUTs... Found !LUT_COUNT! .cube LUT files.
    echo [*] Starting LUT Background Server...
    start "" pythonw.exe "%~dp0lut_service.py"
    timeout /t 1 /nobreak >nul
    echo [OK] Server started on port 8999 with !LUT_COUNT! LUTs loaded.
)
pause
goto MENU

:RESET_LUT
echo.
echo [*] Resetting active LUT in Studio to Stock Rec.709...
curl.exe -s --max-time 1 http://127.0.0.1:8999/reset >nul 2>&1
if !errorlevel! neq 0 (
    copy /y "%~dp0Custom_LUTs\00_Stock_Rec709.cube" "C:\Program Files\Insta360 Studio\data\i_log\X5_I-Log_To_Rec.709_V1.0.cube" >nul
    copy /y "%~dp0Custom_LUTs\00_Stock_Rec709.cube" "C:\Program Files\Insta360 Studio\data\i_log\AcePro2_I-Log_To_Rec.709_V1.0.cube" >nul
    copy /y "%~dp0Custom_LUTs\00_Stock_Rec709.cube" "C:\Program Files\Insta360 Studio\data\i_log\X6_I-Log_To_Rec.709_V1.4.cube" >nul
    copy /y "%~dp0Custom_LUTs\00_Stock_Rec709.cube" "C:\Program Files\Insta360 Studio\data\i_log\Luna_I-Log_to_Rec709.cube" >nul
)
echo [OK] Active LUT reset to clean Stock Rec.709!
pause
goto MENU

:: ---------------------------------------------------------------------
:: 3. FULL RESET
:: ---------------------------------------------------------------------
:RESET_ALL
echo.
echo ===================================================================
echo [!] RESTORING 100%% FACTORY STOCK CONFIGURATION...
echo ===================================================================
echo [*] Closing Insta360 Studio...
taskkill /F /IM "Insta360 Studio.exe" >nul 2>&1
taskkill /F /IM "studio-exporter.exe" >nul 2>&1

echo [*] Stopping LUT Background Server...
powershell -NoProfile -Command "Get-CimInstance Win32_Process | Where-Object { `$_.CommandLine -like '*lut_service.py*' } | ForEach-Object { Stop-Process -Id `$_.ProcessId -Force }" >nul 2>&1

echo [*] Restoring factory stock Insta360 Studio.exe...
copy /y "%~dp0Insta360 Studio_stock.exe" "C:\Program Files\Insta360 Studio\Insta360 Studio.exe" >nul

echo [*] Restoring factory stock studio_worker.dll...
copy /y "%~dp0studio_worker_stock.dll" "C:\Program Files\Insta360 Studio\studio_worker.dll" >nul

echo [*] Restoring factory stock LUTs...
copy /y "%~dp0Custom_LUTs\00_Stock_Rec709.cube" "C:\Program Files\Insta360 Studio\data\i_log\X5_I-Log_To_Rec.709_V1.0.cube" >nul
copy /y "%~dp0Custom_LUTs\00_Stock_Rec709.cube" "C:\Program Files\Insta360 Studio\data\i_log\AcePro2_I-Log_To_Rec.709_V1.0.cube" >nul
copy /y "%~dp0Custom_LUTs\00_Stock_Rec709.cube" "C:\Program Files\Insta360 Studio\data\i_log\X6_I-Log_To_Rec.709_V1.4.cube" >nul
copy /y "%~dp0Custom_LUTs\00_Stock_Rec709.cube" "C:\Program Files\Insta360 Studio\data\i_log\Luna_I-Log_to_Rec709.cube" >nul

if exist "C:\Users\Public\L.qml" del /f /q "C:\Users\Public\L.qml" >nul 2>&1

echo.
echo [✓] SUCCESS: All mods uninstalled. Studio is back to 100%% factory stock!
echo.
pause
goto MENU

:: ---------------------------------------------------------------------
:: 4. TOOLS & SHORTCUTS
:: ---------------------------------------------------------------------
:OPEN_LUTS
start "" "%~dp0Custom_LUTs"
goto MENU

:LAUNCH_PICKER
start "" pythonw.exe "%~dp0Insta360_LUT_Picker.pyw"
goto MENU
