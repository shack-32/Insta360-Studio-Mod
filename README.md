# Insta360 Studio Mod Suite 🚀🎨

Advanced reverse-engineered performance optimizations, export enhancements, Motion ND bypass, and custom 3D LUT color grading pipeline for **Insta360 Studio** (Windows).

---

## ✨ Features

- **⚡ In-App Export Dialog Noise Reduction Toggle (2.4× Export Speedup / Grain Preservation)**:
  - Added an interactive **Noise Reduction** toggle directly inside the in-app video export dialog, positioned conveniently **below the Bitrate setting**.
  - **Default OFF**: Automatically bypasses Insta360 Studio's heavy internal multi-frame spatio-temporal denoise algorithm in `studio_worker.dll`. Cuts export times by **over 50%** (2.4× speedup) while preserving crisp, natural sensor texture and fine organic grain.
  - **Toggle ON**: Instantly re-enables stock multi-frame spatio-temporal noise reduction for that export when smooth digital de-noised footage is needed.
  - Dynamically controlled in real time—no restarting the app or re-patching binaries required!
- **🚫 Complete Motion ND Fix & Export Bypass**:
  - **UI Default OFF**: Patched all 5 media loading paths in `Insta360 Studio.exe` so Motion ND (RealSmartMotionBlur) always starts **OFF** by default on clip load.
  - **Export Render Bypass**: Neutralized the forced motion blur routine in `studio_worker.dll` (`ProjectExporter` and Protobuf filter graph dispatcher). Resolves the bug where exported videos still rendered unwanted motion blur even when switched off in the UI.
- **🎨 In-App Native Look / LUT Selector**:
  - Integrated directly inside the native **Restore LUT** drawer (`InsDrawer`) in the right sidebar.
  - Matches Insta360 Studio's native dark-theme styling seamlessly.
  - Switch looks on the fly—preview canvas updates instantly in real time without restarting the app!
- **🎬 Universal Custom LUT Pipeline**:
  - Unlocks the **Restore LUT** engine for **all** footage (Single Lens, 360°, Flat, Non-Log, Standard profiles).
  - Bakes your custom 3D LUTs directly into final exported videos (`.mp4`, ProRes, etc.), not just preview.
- **🛡️ Crash-Resistant & Safe Fallback**:
  - Prevents startup freezes: Mod launcher ensures safe fallback to stock Rec.709 on launch, preventing the app from getting stuck in corrupt or non-standard LUT files.
  - Dynamic .cube normalizer cleans up whitespace, formatting, and boundary values to keep Qt/QML rock solid.
- **🎛️ Fully Independent Video Adjustments**:
  - Decoupled from the LUT switch: tweak Exposure, Contrast, Saturation, Brilliance, Highlights, Shadows, and Color Plus whether the LUT is **ON** or **OFF**.
  - Turning the LUT off will **never** wipe or grey out your custom color adjustments.
- **🖥️ Unified Mod Launcher & Control Panel (`Insta360 Mod Launcher.bat`)**:
  - Real-time status dashboard displaying LUT server port, loaded LUT count, Fast Export mod status, Motion ND export status, and EXE patch status.
  - Segmented control for 1-click launching, toggling individual features, or performing a clean factory reset.
- **📁 Dynamic LUT Library**:
  - Automatically rescans `Custom_LUTs/` on every launch—drop any `.cube` file into the folder and it appears immediately in the app.

---

## 🚀 Quick Start (Launcher & Control Panel)

### Primary Recommended Method: Mod Launcher
Double-click **`Insta360 Mod Launcher.bat`** in the mod directory.

The interactive launcher provides a live status dashboard and 4 clear segments:
```
========================================================================
             INSTA360 STUDIO MOD LAUNCHER & CONTROL PANEL
========================================================================

  -- STATUS DASHBOARD ----------------------------------------------
     LUT Server Status   : [ ACTIVE - Port 8999 ]
     LUT Library Rescan  : [ 55 .cube LUTs loaded from Custom_LUTs ]
     Noise Reduction Mod : [ IN-APP EXPORT TOGGLE - Default OFF / Grain Preserved ]
     Motion ND Export    : [ BYPASSED - Motion Blur Disabled in Export ]
     Studio EXE Patches  : [ INSTALLED - In-App UI + Sliders Unlocked ]
     Default LUT State   : [ OFF by default / Stock Rec.709 fallback ]
     Motion ND Default   : [ OFF by default on clip load ]
  ------------------------------------------------------------------

  ==================================================================
  == SEGMENT 1: LAUNCH OPTIONS ==
  ==================================================================
    [1] Launch App (Full Mods: Auto-starts server, ensures safe stock LUT)
    [2] Launch App As-Is   (Launches Studio immediately with current state)

  ==================================================================
  == SEGMENT 2: FEATURE TOGGLES (ON / OFF) ==
  ==================================================================
    [3] Toggle 2.4x Fast Export Mod       (Bypass AI denoise in DLL)
    [4] Toggle In-App LUT UI & EXE Patch (Install / Remove EXE mods)
    [5] Toggle LUT Background Server     (Start / Stop port 8999 service)
    [6] Safe Reset Active LUT to Stock   (Restore Stock Rec.709 in i_log)

  ==================================================================
  == SEGMENT 3: FULL RESET ==
  ==================================================================
    [7] Reset All to Stock (Full Factory Uninstall: Restore factory binaries)

  ==================================================================
  == SEGMENT 4: TOOLS & SHORTCUTS ==
  ==================================================================
    [8] Open Custom LUTs Folder (Add / Remove .cube files)
    [9] Launch Standalone Floating LUT Picker Window
    [0] Exit
```

- Choose **`1`** to run with full mods (auto-starts background service, deploys verified DLL/EXE mods, and opens Insta360 Studio).
- Choose **`2`** to launch Studio as-is without changing any current mod states.
- Choose **`7`** anytime for an instant, clean factory restore of all original unmodified binaries.

---

## 🎬 How to Use the In-App LUT Selector

1. Open **Insta360 Studio** via the Mod Launcher.
2. Open any video clip (Single Lens, 360°, Flat, or Standard).
3. In the right sidebar panel, click **Restore LUT** to expand the drawer.
4. Toggle the switch to **ON**.
5. Select your desired look from the dropdown (e.g. Kodak 2383, CineStill 800T, Analog Film, Teal & Orange, etc.).
6. The preview updates instantly in real time!
7. Click **Export**—your video exports at **2.4× speed** with your custom LUT baked in, and without any unwanted Motion ND blur.

---

## 🛠️ Complete Binary Patch Map (13 Verified Patches)

All patches are codified in [`patches.json`](patches.json) with exact byte offsets and disassembled opcodes:

| Target | File Offset | Virtual Address | Original Opcode | Patched Opcode | Functionality |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `studio_worker.dll` | `0x31CE730` | `0x1831CF130` | `48 89 5C 24 18 55` | `31 C0 C3 90 90 90` | **2.4× Fast Export (Denoise Bypass)**: Returns `0` immediately from multi-frame denoiser. |
| `studio_worker.dll` | `0x318F7D4` | `0x1831901D4` | `0F 84 A4 01 00 00` | `E9 A5 01 00 00 90` | **Motion ND Export Bypass (ProjectExporter)**: Unconditionally skips RSMB filter instantiation during export. |
| `studio_worker.dll` | `0x31C5B13` | `0x1831C6513` | `48 8B 82 88 00 00 00` | `E9 2C FF FF FF 90 90` | **Motion ND Export Bypass (FilterDispatcher)**: Bypasses RSMB filter graph node type `0xf` in export queue. |
| `Insta360 Studio.exe` | `0x30119C0` | `0x1430123C0` | `0F B6 41 1D C3` | `B0 01 C3 90 90` | **Universal LUT Engine**: `supportLut` getter returns `1` for all clips (Flat, 360°, Non-Log). |
| `Insta360 Studio.exe` | `0x3750A25` | `0x143751425` | `0F B6 D0` | `31 D2 90` | **Default LUT State Off**: Clears `dl` (`xor edx, edx`) so LUT is never enabled by default on clip load. |
| `Insta360 Studio.exe` | `0x375087D` | `0x14375127D` | `B2 01` | `31 D2` | **Default Motion ND Off (Loader 1)**: Clears `enableMotionBlur` flag on primary media load. |
| `Insta360 Studio.exe` | `0x379FB64` | `0x1437A0564` | `0F B6 D3` | `31 D2 90` | **Default Motion ND Off (Loader 2)**: Clears `enableMotionBlur` in secondary media loader. |
| `Insta360 Studio.exe` | `0x33FB74B` | `0x1433FC14B` | `B2 01` | `31 D2` | **Default Motion ND Off (Loader 3)**: Clears `enableMotionBlur` in tertiary media loader. |
| `Insta360 Studio.exe` | `0x30262E2` | `0x143026CE2` | `40 0F B6 D7` | `31 D2 90 90` | **Default Motion ND Off (Loader 4)**: Clears `enableMotionBlur` in project loader path A. |
| `Insta360 Studio.exe` | `0x302633D` | `0x143026D3D` | `0F B6 D3` | `31 D2 90` | **Default Motion ND Off (Loader 5)**: Clears `enableMotionBlur` in project loader path B. |
| `Insta360 Studio.exe` | `0x35A3440` | `0x1435A3E40` | `40 53 48 83 EC 20` | `B0 01 C3 90 90 90` | **Video Adjustments Unlock**: Decouples color grading sliders from LUT state. |
| `Insta360 Studio.exe` | `0x35A3480` | `0x1435A3E80` | `40 53 48 83 EC 20` | `C3 90 90 90 90 90` | **Adjustment Reset Hook Bypass**: Neutralizes callback that wiped color adjustments when LUT toggled off. |
| `Insta360 Studio.exe` | `0x3011930` | `0x143012330` | `0F B6 41 1A C3` | `B0 01 C3 90 90` | **filtersModifiable Unlock**: Prevents UI sliders from greying out when LUT switch is toggled off. |
| `Insta360 Studio.exe` | `0x6B31BEF` | — | *(Stock LutView.qml)* | *(InsDrawer + Loader)* | **In-App Look Dropdown**: Embeds native QtQuick Loader inside `InsDrawer` pointing to `Public/L.qml`. |

---

## 📂 Repository Contents

- **`Insta360 Mod Launcher.bat`**: Primary interactive launcher and control panel with live mod status dashboard.
- **`ToggleDenoise.ps1`**: PowerShell backend manager for status inspection and mod switching.
- **`patch_studio.py`**: Standalone cross-platform binary patching engine.
- **`patches.json`**: Complete machine-readable database of all 13 binary patches (v1.2).
- **`L.qml`**: Native Qt Quick component implementing the in-app look selector dropdown.
- **`lut_service.py`**: Background local service (port 8999) providing dynamic LUT rescanning and normalization.
- **`Insta360_LUT_Picker.pyw`**: Optional standalone floating GUI for external LUT switching.
- **`Custom_LUTs/`**: Curated library of 42 cinematic 3D `.cube` LUTs.

---

## ⚖️ Disclaimer

This project is an independent reverse-engineering and modding suite created for educational and workflow-enhancement purposes. All trademarks, software copyrights, and assets belong to Insta360 / Arashi Vision Inc.
