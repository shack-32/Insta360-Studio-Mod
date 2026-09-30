<#
.SYNOPSIS
    Insta360 Studio Mod Suite Installer & Manager
.DESCRIPTION
    Applies 2.4x export speedup, universal custom LUT support, in-app native
    LUT selector dropdown, and unlocked video adjustments.
#>
param(
    [string]$InstallDir = "C:\Program Files\Insta360 Studio",
    [switch]$Uninstall
)

# Auto-elevate to Administrator if needed
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "Requesting Administrator privileges..." -ForegroundColor Yellow
    $argList = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    if ($Uninstall) { $argList += " -Uninstall" }
    Start-Process powershell.exe -ArgumentList $argList -Verb RunAs
    exit
}

$ScriptDir = $PSScriptRoot
$PythonScript = Join-Path $ScriptDir "patch_studio.py"
$QmlSource = Join-Path $ScriptDir "LutContent.qml"
$QmlDestDir = Join-Path $InstallDir "data\i_log"
$QmlDest = Join-Path $QmlDestDir "LutContent.qml"
$ServiceScript = Join-Path $ScriptDir "lut_service.py"
$RegPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
$RegKey = "Insta360LutService"

Write-Host "===========================================================" -ForegroundColor Cyan
Write-Host "       Insta360 Studio Mod Suite - Automated Installer     " -ForegroundColor Cyan
Write-Host "===========================================================" -ForegroundColor Cyan

if (-not (Test-Path $InstallDir)) {
    Write-Host "[!] Insta360 Studio installation not found at: $InstallDir" -ForegroundColor Red
    pause
    exit
}

# Run patch_studio.py
$pyArgs = @("`"$PythonScript`"", "`"$InstallDir`"")
if ($Uninstall) { $pyArgs += "--restore" }

Write-Host "`nRunning binary patcher..." -ForegroundColor Yellow
Start-Process python -ArgumentList $pyArgs -NoNewWindow -Wait

$pythonw = "C:\Users\shane\AppData\Local\Python\bin\pythonw.exe"
if (-not (Test-Path $pythonw)) { $pythonw = "pythonw.exe" }

if ($Uninstall) {
    # Uninstall procedures
    Write-Host "`nRemoving autostart service and files..." -ForegroundColor Yellow
    Remove-ItemProperty -Path $RegPath -Name $RegKey -ErrorAction SilentlyContinue
    if (Test-Path $QmlDest) { Remove-Item $QmlDest -Force -ErrorAction SilentlyContinue }
    
    # Remove Desktop Shortcuts
    $desktop = [Environment]::GetFolderPath('Desktop')
    $s1Path = Join-Path $desktop "Insta360 Live LUT Selector.lnk"
    $s2Path = Join-Path $desktop "Insta360 Mod Manager & Denoise Switcher.lnk"
    if (Test-Path $s1Path) { Remove-Item $s1Path -Force }
    if (Test-Path $s2Path) { Remove-Item $s2Path -Force }
    Write-Host "[✓] Uninstalled successfully." -ForegroundColor Green
} else {
    # Install procedures
    Write-Host "`nDeploying QML UI components..." -ForegroundColor Yellow
    if (Test-Path $QmlSource) {
        Copy-Item -Path $QmlSource -Destination $QmlDest -Force
        Write-Host "[✓] Deployed LutContent.qml to $QmlDest" -ForegroundColor Green
    }

    # Grant write permissions to data\i_log for background switcher
    icacls $QmlDestDir /grant "Users:(OI)(CI)F" /T | Out-Null

    # Configure Autostart for Background LUT Switcher Service
    Write-Host "`nConfiguring Background LUT Switcher Service..." -ForegroundColor Yellow
    Set-ItemProperty -Path $RegPath -Name $RegKey -Value "`"$pythonw`" `"$ServiceScript`""
    Write-Host "[✓] Registered in HKCU Run registry." -ForegroundColor Green

    # Launch service if not currently running
    $isRunning = $false
    try {
        $resp = Invoke-RestMethod -Uri "http://127.0.0.1:8999/list" -TimeoutSec 2 -ErrorAction Stop
        if ($resp) { $isRunning = $true }
    } catch {}

    if (-not $isRunning) {
        Write-Host "[*] Starting background LUT service..." -ForegroundColor Yellow
        Start-Process -FilePath $pythonw -ArgumentList "`"$ServiceScript`"" -WorkingDirectory $ScriptDir
    }
    Write-Host "[✓] Background LUT service active on http://127.0.0.1:8999" -ForegroundColor Green

    # Create Desktop shortcuts
    Write-Host "`nConfiguring Desktop Shortcuts..." -ForegroundColor Yellow
    $desktop = [Environment]::GetFolderPath('Desktop')
    $ws = New-Object -ComObject WScript.Shell
    $iconPath = Join-Path $InstallDir "Insta360 Studio.exe,0"

    # 1. Standalone LUT Picker Shortcut
    $s1 = $ws.CreateShortcut((Join-Path $desktop "Insta360 Live LUT Selector.lnk"))
    $s1.TargetPath = $pythonw
    $s1.Arguments = "`"" + (Join-Path $ScriptDir "Insta360_LUT_Picker.pyw") + "`""
    $s1.WorkingDirectory = $ScriptDir
    $s1.IconLocation = $iconPath
    $s1.Description = "Real-time Live LUT Switcher for Insta360 Studio"
    $s1.Save()

    # 2. Mod Manager Shortcut
    $s2 = $ws.CreateShortcut((Join-Path $desktop "Insta360 Mod Manager & Denoise Switcher.lnk"))
    $s2.TargetPath = "powershell.exe"
    $s2.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"" + (Join-Path $ScriptDir "ToggleDenoise.ps1") + "`""
    $s2.WorkingDirectory = $ScriptDir
    $s2.IconLocation = $iconPath
    $s2.Description = "Toggle Denoise, Deploy Mods, Manage LUTs"
    $s2.Save()

    Write-Host "[✓] Desktop shortcuts verified." -ForegroundColor Green
}

Write-Host "`nOperation completed successfully." -ForegroundColor Green
Start-Sleep -Seconds 2
