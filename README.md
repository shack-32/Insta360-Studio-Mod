# Insta360 Studio Mod Suite 🚀🎨

Advanced reverse-engineered performance optimizations, export enhancements, and custom LUT color grading pipeline for **Insta360 Studio** (Windows).

---

## ✨ Features

- **⚡ 2.4× Export Speedup (Denoise Bypass)**:
  - Bypasses Insta360 Studio's heavy internal multi-frame spatio-temporal denoise algorithm.
  - Cuts export times by **over 50%** (e.g., 60 seconds down to 25 seconds).
  - Preserves fine, natural sensor texture and crisp organic grain instead of digital over-smoothing / plastic skin artifacts.
- **🎨 Universal Custom LUT Pipeline**:
  - Unlocks the **Restore LUT** engine for **all** footage (Single Lens, 360°, Flat, Non-Log, Standard profiles).
  - Bakes your custom 3D LUTs directly into final exported videos (`.mp4`, ProRes, etc.), not just preview.
- **🎛️ Fully Independent Video Adjustments**:
  - Decoupled from the LUT switch. You can tweak Exposure, Contrast, Saturation, Brilliance, Highlights, Shadows, and Color Plus whether the LUT is **ON** or **OFF**.
  - Turning the LUT off will **never** lock or wipe your color adjustments.
- **🔄 Real-Time Live LUT Switcher**:
  - Floating dark-mode companion tool (`Insta360 Live LUT Selector`) that stays alongside Studio.
  - Switch between any `.cube` LUT in real time with a single click.
  - Flip the LUT toggle OFF then ON in Studio to reload live—**zero app restarts required**.
- **📁 Drag-and-Drop LUT Library**:
  - Includes a curated pack of 24 cinematic look LUTs (Kodak 2383, CineStill 800T, Night Vision, Teal/Orange, S-Log conversions, etc.).
  - Drop any standard `.cube` file into the `Custom_LUTs` folder to use it immediately.

---

## 🚀 Quick Start (Installation)

### Method 1: Automatic 1-Click Installer (Recommended)
1. Clone this repository:
   ```cmd
   git clone https://github.com/shack-32/Insta360-Studio-Mod.git
   cd Insta360-Studio-Mod
   ```
2. Right-click **`Install-Insta360Mod.bat`** and select **Run as Administrator** (or run `Install-Insta360Mod.ps1`).
3. The installer will automatically:
   - Create clean backups of your original binaries (`.stock`).
   - Apply all binary patches in-place.
   - Configure Desktop shortcuts for the **Live LUT Selector** and **Mod Manager**.

### Method 2: Python Patcher
```cmd
python patch_studio.py
```
To revert back to original stock binaries at any time:
```cmd
python patch_studio.py --restore
```

---

## 🎬 How to Use the Live LUT Switcher

1. Double-click the **Insta360 Live LUT Selector** desktop shortcut.
2. Select any LUT from the dropdown menu (or click **📁 Open LUTs Folder** to drop in your own `.cube` files).
3. In **Insta360 Studio**: Flip the **Restore LUT** switch **OFF then ON**.
4. Studio will immediately re-read the active `.cube` file and update your playback and preview in real time!
5. Export your video—the selected LUT is cleanly baked into the exported file with the 2.4× export speedup.

---

## 🛠️ Technical Details & Binary Patch Map

All patches are documented in [`patches.json`](patches.json) with exact byte offsets and disassembled instructions:

| Target | File Offset | Virtual Address | Original Opcode | Patched Opcode | Functionality |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `studio_worker.dll` | `0x31CE730` | `0x1831CF130` | `48 89 5C 24 18 55` | `31 C0 C3 90 90 90` | **Denoise Bypass**: Forces multi-frame denoiser function to return 0 immediately (2.4× export speedup). |
| `studio_worker.dll` | `0x31E2352` | `0x1831E2D52` | `88 86 FC 01 00 00` | `8A 86 A2 00 00 00 88 86 FC 01 00 00` | **Export LUT Forwarding**: Forwards UI `enable_lut` (`[rsi+0xa2]`) to export pipeline (`[rsi+0x1fc]`). |
| `Insta360 Studio.exe` | `0x30119C0` | `0x1430123C0` | `0F B6 41 1D C3` | `B0 01 C3 90 90` | **Universal LUT Engine**: `supportLut` getter returns `1` for all clips. |
| `Insta360 Studio.exe` | `0x3750A25` | `0x143751425` | `0F B6 D0` | `B2 01 90` | **Media Load Flag**: Sets LUT property flag on clip open. |
| `Insta360 Studio.exe` | `0x35A3440` | `0x1435A3E40` | `40 53 48 83 EC 20` | `B0 01 C3 90 90 90` | **Filters Modifiable Unlock**: `filtersModifiable()` returns `1`, decoupling color grading from LUT state. |
| `Insta360 Studio.exe` | `0x35A3480` | `0x1435A3E80` | `40 53 48 83 EC 20` | `C3 90 90 90 90 90` | **Adjustment Reset Bypass**: Neutralizes callback that wiped color adjustments when LUT was toggled off. |
| `Insta360 Studio.exe` | `0x6B31D00` | — | `viewModel.supportLut` | `true                ` | **QML UI Unlock**: Keeps "Restore LUT" drawer visible for all video formats. |

---

## 📂 Repository Contents

- `Install-Insta360Mod.ps1` & `Install-Insta360Mod.bat`: One-click installer and uninstaller.
- `patch_studio.py`: Standalone cross-platform patch engine.
- `patches.json`: Machine-readable byte patch definitions.
- `ToggleDenoise.ps1`: Interactive terminal control panel to toggle mods and manage presets.
- `Insta360_LUT_Picker.pyw`: Real-time GUI LUT switcher.
- `Custom_LUTs/`: Pack of 24 3D cinematic `.cube` LUTs.
- `sharpen_param_*.json`: Edge-enhancement tuning presets (Stock, Soft, Off).

---

## ⚖️ Disclaimer

This project is an independent community modification for educational and workflow-enhancement purposes. All trademarks and software copyrights belong to Insta360 / Arashi Vision Inc.
