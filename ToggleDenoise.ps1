param (
    [switch]$PureCinema,
    [switch]$Stock,
    [switch]$DeployAll,
    [switch]$StatusOnly
)

# Elevate if not Administrator and running interactively
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin -and -not $StatusOnly) {
    if ([Environment]::UserInteractive) {
        try {
            $argList = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
            if ($PureCinema) { $argList += " -PureCinema" }
            if ($Stock)      { $argList += " -Stock" }
            if ($DeployAll)  { $argList += " -DeployAll" }
            Start-Process powershell.exe -ArgumentList $argList -Verb RunAs -ErrorAction Stop
            exit
        } catch {
            Write-Warning "Could not auto-elevate: $_"
            Write-Host "Please right-click the script or shortcut and select 'Run as Administrator'." -ForegroundColor Red
        }
    }
}

$InstallDir   = "C:\Program Files\Insta360 Studio"
$TargetExe    = Join-Path $InstallDir "Insta360 Studio.exe"
$TargetDll    = Join-Path $InstallDir "studio_worker.dll"
$TargetJson   = Join-Path $InstallDir "data\sharpen_param.json"
$TargetLutDir = Join-Path $InstallDir "data\i_log"
$AppExe       = $TargetExe

$ScriptDir    = $PSScriptRoot
$StockExe     = Join-Path $ScriptDir "Insta360 Studio_stock.exe"
$PatchedExe   = Join-Path $ScriptDir "Insta360 Studio_lutmod.exe"

$StockDll     = Join-Path $ScriptDir "studio_worker_stock.dll"
$PatchedDll   = Join-Path $ScriptDir "studio_worker_nodenoise.dll"

$StockJson    = Join-Path $ScriptDir "sharpen_param_stock.json"
$OffJson      = Join-Path $ScriptDir "sharpen_param_off.json"
$SoftJson     = Join-Path $ScriptDir "sharpen_param_soft.json"

$CustomLutDir = Join-Path $ScriptDir "Custom_LUTs"
if (-not (Test-Path $CustomLutDir)) { New-Item -ItemType Directory -Path $CustomLutDir -Force | Out-Null }

function Get-DenoiseStatus {
    param($Path)
    if (-not (Test-Path $Path)) { return "NOT FOUND" }
    try {
        $stream = [System.IO.File]::OpenRead($Path)
        $stream.Seek(0x31CEC0E, [System.IO.SeekOrigin]::Begin) | Out-Null
        $buf = New-Object byte[] 5
        $stream.Read($buf, 0, 5) | Out-Null
        $stream.Close()
        $hex = [System.BitConverter]::ToString($buf) -replace '-', ''
        if ($hex -eq "E83DFB8903") { return "IN-APP TOGGLE (Export Dialog Controlled - Default OFF / Grain Preserved)" }

        $stream = [System.IO.File]::OpenRead($Path)
        $stream.Seek(0x31CE730, [System.IO.SeekOrigin]::Begin) | Out-Null
        $buf = New-Object byte[] 6
        $stream.Read($buf, 0, 6) | Out-Null
        $stream.Close()
        $hex2 = [System.BitConverter]::ToString($buf) -replace '-', ''
        if ($hex2 -eq "31C0C3909090") { return "OFF (Bypassed - 2.4x Faster, Natural Grain)" }
        if ($hex2 -eq "48895C241855") { return "ON (Stock - Multi-Frame Denoise Active)" }
        return "UNKNOWN ($hex)"
    } catch {
        return "ERROR: $_"
    }
}

function Get-LutUiStatus {
    param($Path)
    if (-not (Test-Path $Path)) { return "NOT FOUND" }
    try {
        $stream = [System.IO.File]::OpenRead($Path)
        $stream.Seek(0x6B31CF7, [System.IO.SeekOrigin]::Begin) | Out-Null
        $buf = New-Object byte[] 29
        $stream.Read($buf, 0, 29) | Out-Null
        $stream.Close()
        $text = [System.Text.Encoding]::ASCII.GetString($buf)
        if ($text.StartsWith("visible: true")) { return "UNLOCKED (Visible for All Videos)" }
        if ($text.StartsWith("visible: viewModel.supportLut")) { return "STOCK (i-Log Only)" }
        return "CUSTOM"
    } catch {
        return "ERROR: $_"
    }
}

function Get-MotionNdExportStatus {
    param($Path)
    if (-not (Test-Path $Path)) { return "NOT FOUND" }
    try {
        $stream = [System.IO.File]::OpenRead($Path)
        $stream.Seek(0x318F7D4, [System.IO.SeekOrigin]::Begin) | Out-Null
        $buf = New-Object byte[] 6
        $stream.Read($buf, 0, 6) | Out-Null
        $stream.Close()
        $hex = [System.BitConverter]::ToString($buf) -replace '-', ''
        if ($hex -eq "E9A501000090") { return "OFF (Bypassed - No Motion Blur in Export)" }
        if ($hex -eq "0F84A4010000") { return "STOCK (Motion Blur Render Enabled)" }
        return "CUSTOM ($hex)"
    } catch {
        return "ERROR: $_"
    }
}

function Get-ActiveLutName {
    $x5Lut = Join-Path $TargetLutDir "X5_I-Log_To_Rec.709_V1.0.cube"
    if (-not (Test-Path $x5Lut)) { return "NONE" }
    $firstLine = Get-Content $x5Lut -TotalCount 1
    if ($firstLine -match 'TITLE\s+"?([^"]+)"?') {
        return $matches[1]
    }
    return "Custom (.cube active)"
}

if ($StatusOnly) {
    Write-Host "Denoise: $(Get-DenoiseStatus -Path $TargetDll)"
    Write-Host "LUT UI:  $(Get-LutUiStatus -Path $TargetExe)"
    Write-Host "Motion ND Export: $(Get-MotionNdExportStatus -Path $TargetDll)"
    Write-Host "Active LUT Title: $(Get-ActiveLutName)"
    return
}

function Stop-StudioProcesses {
    Get-Process "Insta360 Studio", "studio-exporter-service", "studio_utility" -ErrorAction SilentlyContinue | Stop-Process -Force
    Start-Sleep -Milliseconds 400
}

function Deploy-AllMods {
    Stop-StudioProcesses
    Write-Host "`n  Deploying All Mods (LUT Export Fix + Denoise Bypass + Universal LUT UI)..." -ForegroundColor Cyan
    Copy-Item -Path $PatchedDll -Destination $TargetDll -Force
    Copy-Item -Path $PatchedExe -Destination $TargetExe -Force
    try {
        icacls $TargetDll /grant Users:F | Out-Null
        icacls $TargetExe /grant Users:F | Out-Null
        icacls $TargetLutDir /grant "Users:(OI)(CI)F" /T | Out-Null
    } catch {}
    Write-Host "  [OK] All Mods Deployed Successfully & Direct File Permissions Granted!" -ForegroundColor Green
}

if ($DeployAll) {
    Deploy-AllMods
    Write-Host "`n  [OK] Deployment complete! You can now launch Studio and export." -ForegroundColor Green
    Start-Sleep -Seconds 3
    return
}

function Set-Denoise {
    param([bool]$Enable)
    Stop-StudioProcesses
    if ($Enable) {
        Copy-Item -Path $StockDll -Destination $TargetDll -Force
        Write-Host "  -> Multi-Frame Denoise set to: ON (Stock)" -ForegroundColor Yellow
    } else {
        Copy-Item -Path $PatchedDll -Destination $TargetDll -Force
        Write-Host "  -> Multi-Frame Denoise set to: OFF (Bypassed)" -ForegroundColor Green
    }
}

function Set-LutUiUnlock {
    param([bool]$Unlock)
    Stop-StudioProcesses
    if ($Unlock) {
        Copy-Item -Path $PatchedExe -Destination $TargetExe -Force
        Write-Host "  -> LUT Toggle set to: UNLOCKED FOR ALL VIDEOS" -ForegroundColor Green
    } else {
        Copy-Item -Path $StockExe -Destination $TargetExe -Force
        Write-Host "  -> LUT Toggle set to: STOCK (i-Log Only)" -ForegroundColor Yellow
    }
}

function Set-ActiveLut {
    param([string]$LutFilePath)
    if (-not (Test-Path $LutFilePath)) { return }
    Stop-StudioProcesses
    $lutName = [System.IO.Path]::GetFileName($LutFilePath)
    Write-Host "  Deploying LUT '$lutName' to Studio..." -ForegroundColor Cyan
    # Deploy to all known camera profile targets so any footage picks it up
    $targets = @(
        "X5_I-Log_To_Rec.709_V1.0.cube",
        "AcePro2_I-Log_To_Rec.709_V1.0.cube",
        "X6_I-Log_To_Rec.709_V1.4.cube",
        "Luna_I-Log_to_Rec709.cube"
    )
    foreach ($t in $targets) {
        $dest = Join-Path $TargetLutDir $t
        Copy-Item -Path $LutFilePath -Destination $dest -Force
    }
    Write-Host "  [OK] Custom LUT '$lutName' is now active!" -ForegroundColor Green
}

function Launch-App {
    Write-Host "`n  Launching Insta360 Studio..." -ForegroundColor Cyan
    Start-Process -FilePath $AppExe
    Start-Sleep -Seconds 2
}

# Interactive Menu
while ($true) {
    Clear-Host
    Write-Host "=================================================================" -ForegroundColor Cyan
    Write-Host "    Insta360 Studio - Export Optimizer & Custom LUT Manager      " -ForegroundColor Cyan
    Write-Host "=================================================================" -ForegroundColor Cyan

    $dStatus = Get-DenoiseStatus -Path $TargetDll
    $lStatus = Get-LutUiStatus -Path $TargetExe
    $eStatus = Get-MotionNdExportStatus -Path $TargetDll
    $lutName = Get-ActiveLutName

    Write-Host ""
    Write-Host "  Active Status:" -ForegroundColor Gray
    Write-Host "    * Multi-Frame Denoise: " -NoNewline
    if ($dStatus -like "*OFF*") { Write-Host $dStatus -ForegroundColor Green } else { Write-Host $dStatus -ForegroundColor Yellow }

    Write-Host "    * LUT Toggle in Studio: " -NoNewline
    if ($lStatus -like "*UNLOCKED*") { Write-Host $lStatus -ForegroundColor Green } else { Write-Host $lStatus -ForegroundColor Yellow }

    Write-Host "    * Motion ND Export:     " -NoNewline
    if ($eStatus -like "*CLEAN*") { Write-Host $eStatus -ForegroundColor Green } else { Write-Host $eStatus -ForegroundColor Yellow }

    Write-Host "    * Current Active LUT:   " -NoNewline
    Write-Host "$lutName" -ForegroundColor Cyan

    Write-Host ""
    Write-Host "  ---------------------------------------------------------------" -ForegroundColor DarkGray
    Write-Host "  OPTIONS:" -ForegroundColor White
    Write-Host "    [1] Deploy / Update ALL Mods (Custom LUT Export Fix + Denoise Off + UI Unlock)" -ForegroundColor Green
    Write-Host "    [2] Select / Switch Active LUT from Custom_LUTs folder" -ForegroundColor White
    Write-Host "    [3] Open Custom_LUTs folder (Drop your .cube files here)" -ForegroundColor White
    Write-Host "    [4] Toggle Denoise (Currently: $(if ($dStatus -like '*OFF*') {'OFF'} else {'ON'}))" -ForegroundColor White
    Write-Host "    [5] Restore Factory Defaults (Stock DLL, Stock Exe, Stock LUT)" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  LAUNCH & EXIT:" -ForegroundColor White
    Write-Host "    [6] Launch Insta360 Studio" -ForegroundColor Cyan
    Write-Host "    [7] Exit" -ForegroundColor DarkGray
    Write-Host ""

    $choice = Read-Host "  Select an option [1-7]"

    switch ($choice) {
        "1" {
            Deploy-AllMods
            Start-Sleep -Seconds 2
        }
        "2" {
            $cubeFiles = Get-ChildItem -Path $CustomLutDir -Filter "*.cube"
            if ($cubeFiles.Count -eq 0) {
                Write-Host "`n  No .cube files found in Custom_LUTs folder!" -ForegroundColor Red
                Write-Host "  Drop your .cube files into: $CustomLutDir" -ForegroundColor Yellow
                Start-Sleep -Seconds 3
            } else {
                Write-Host "`n  Available LUTs in Custom_LUTs:" -ForegroundColor Cyan
                for ($i = 0; $i -lt $cubeFiles.Count; $i++) {
                    Write-Host "    [$($i+1)] $($cubeFiles[$i].Name)" -ForegroundColor White
                }
                Write-Host "    [B] Back" -ForegroundColor Gray
                $lutPick = Read-Host "`n  Choose a LUT to activate [1-$($cubeFiles.Count)]"
                if ($lutPick -match '^\d+$' -and [int]$lutPick -ge 1 -and [int]$lutPick -le $cubeFiles.Count) {
                    $selectedFile = $cubeFiles[[int]$lutPick - 1].FullName
                    Set-ActiveLut -LutFilePath $selectedFile
                    Start-Sleep -Seconds 2
                }
            }
        }
        "3" {
            Invoke-Item $CustomLutDir
        }
        "4" {
            if ($dStatus -like "*OFF*") {
                Set-Denoise -Enable $true
            } else {
                Set-Denoise -Enable $false
            }
            Start-Sleep -Seconds 1
        }
        "5" {
            Write-Host "`n  Restoring original Insta360 stock components..." -ForegroundColor Yellow
            Set-Denoise -Enable $true
            Set-LutUiUnlock -Unlock $false
            $stockLutPath = Join-Path $CustomLutDir "X5_Stock_Rec709.cube"
            if (Test-Path $stockLutPath) { Set-ActiveLut -LutFilePath $stockLutPath }
            Write-Host "  [OK] Factory stock configuration restored." -ForegroundColor Green
            Start-Sleep -Seconds 2
        }
        "6" {
            Launch-App
            break
        }
        default {
            Write-Host "`n  Exiting." -ForegroundColor Gray
            break
        }
    }
    if ($choice -in @("6","7")) { break }
}
