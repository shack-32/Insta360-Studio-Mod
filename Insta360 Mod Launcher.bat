@echo off
setlocal enabledelayedexpansion
title Insta360 Studio Mod Launcher ^& Control Panel
cd /d "%~dp0"

:: Check for Administrative privileges and elevate if needed
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo [*] Administrative privileges required to manage files in Program Files.
    echo [*] Requesting UAC elevation...
    powershell -NoProfile -Command "Start-Process cmd.exe -ArgumentList '/c \"\"%~f0\"\"' -Verb RunAs"
    exit /b
)

:MENU
cls
echo ========================================================================
echo              INSTA360 STUDIO MOD LAUNCHER ^& CONTROL PANEL
echo ========================================================================
echo.

:: Query Mod Status using Dynamic Signature Patcher
set "LUT_STATUS=[ ... ]"
set "MND_STATUS=[ ... ]"
set "DENOISE_STATUS=[ ... ]"
set "SERVER_STATUS=[ ... ]"
for /f "tokens=1,* delims=:" %%A in ('python "%~dp0dynamic_patcher.py" --status 2^>nul') do (
    if "%%A"=="LUT" set "LUT_STATUS=[ %%B ]"
    if "%%A"=="MND" set "MND_STATUS=[ %%B ]"
    if "%%A"=="Denoise" set "DENOISE_STATUS=[ %%B ]"
    if "%%A"=="Server" set "SERVER_STATUS=[ %%B ]"
)

:: Dynamic Rescan of Custom_LUTs folder
set "LUT_COUNT=0"
for /f %%A in ('powershell -NoProfile -Command "(Get-ChildItem -Path '%~dp0Custom_LUTs' -Filter '*.cube' -File -ErrorAction SilentlyContinue).Count"') do set "LUT_COUNT=%%A"

echo   -- STATUS DASHBOARD ----------------------------------------------
echo      LUT Server Status   : %SERVER_STATUS%
echo      LUT Library Rescan  : [ !LUT_COUNT! .cube LUTs loaded from Custom_LUTs ]
echo      Noise Reduction Mod : %DENOISE_STATUS%
echo      Motion ND Export    : %MND_STATUS%
echo      Studio EXE Patches  : %LUT_STATUS%
echo      Default LUT State   : [ OFF by default / Stock Rec.709 fallback ]
echo      Motion ND Default   : [ OFF by default on clip load ]
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
echo     [3] Toggle Noise Reduction Mod        (In-App Export Dialog Hook / Stock DLL)
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
echo     [P] Launch Dynamic Signature Patcher (Scan ^& Patch Any New Update)
echo     [0] Exit
echo   ==================================================================
echo.
set /p opt="Select an option [0-9, P] (Default 1): "
if "%opt%"=="" set opt=1

if /i "%opt%"=="P" goto LAUNCH_DYNAMIC_PATCHER
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

:LAUNCH_DYNAMIC_PATCHER
echo.
echo [*] Launching Dynamic Signature Patcher...
python "%~dp0dynamic_patcher.py"
echo.
echo [*] Patcher session completed.
pause
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

:: Ensure modded state is applied dynamically
echo %LUT_STATUS% | findstr /i "PATCHED" >nul
if !errorlevel! neq 0 (
    echo [*] Applying Dynamic Patches to current Studio installation...
    python "%~dp0dynamic_patcher.py" --all
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
echo [*] Toggling 2.4x Fast Export Denoise Bypass dynamically...
python "%~dp0dynamic_patcher.py" --denoise
pause
goto MENU

:TOGGLE_EXE_PATCH
echo.
echo [*] Toggling Studio EXE patches dynamically...
python "%~dp0dynamic_patcher.py" --lut
copy /y "%~dp0L.qml" "C:\Users\Public\L.qml" >nul 2>&1
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

echo [*] Restoring factory stock binaries from backup via Dynamic Patcher...
python "%~dp0dynamic_patcher.py" --restore

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
