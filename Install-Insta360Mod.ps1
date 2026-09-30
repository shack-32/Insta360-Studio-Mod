<#
.SYNOPSIS
    Insta360 Studio Mod Suite Installer
.DESCRIPTION
    Applies 2.4x export speedup, universal custom LUT support, live LUT switcher,
    and video adjustment independence patches.
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

# Create Desktop shortcuts if installing
if (-not $Uninstall) {
    Write-Host "`nConfiguring Desktop Shortcuts..." -ForegroundColor Yellow
    $desktop = [Environment]::GetFolderPath('Desktop')
    $ws = New-Object -ComObject WScript.Shell
    $iconPath = Join-Path $InstallDir "Insta360 Studio.exe,0"
    $pythonw = "C:\Users\shane\AppData\Local\Python\bin\pythonw.exe"
    if (-not (Test-Path $pythonw)) { $pythonw = "pythonw.exe" }

    # 1. LUT Selector Shortcut
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
