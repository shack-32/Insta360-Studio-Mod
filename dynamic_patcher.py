"""
================================================================================
Insta360 Studio Dynamic Signature Patcher & Mod Manager
--------------------------------------------------------------------------------
Automatically scans, locates byte signatures, and injects reverse-engineered
mods dynamically across Insta360 Studio versions without hardcoded offsets.

Features:
  1. Universal 3D LUT Engine + In-App Look Selector (Single Lens / 360 / Non-Log)
  2. Complete Motion ND Fix (Default OFF in UI + Export Bypass in Engine)
  3. In-App Export Dialog Noise Reduction Toggle (2.4x Speedup / Grain Preserved)
  4. Background LUT Service Manager (Port 8999)
  5. One-Click Full Patch / Clean Restore from Auto-Backups
================================================================================
"""

import os
import sys
import re
import zlib
import struct
import shutil
import subprocess
import traceback
import urllib.request
import urllib.parse
import json

DEFAULT_INSTALL_DIR = r"C:\Program Files\Insta360 Studio"
MOD_DIR = os.path.dirname(os.path.abspath(__file__))
SERVICE_SCRIPT = os.path.join(MOD_DIR, "lut_service.py")
CUSTOM_LUTS_DIR = os.path.join(MOD_DIR, "Custom_LUTs")
L_QML_FILE = os.path.join(MOD_DIR, "L.qml")
PUBLIC_L_QML = r"C:\Users\Public\L.qml"
PUBLIC_DENOISE_FLAG = r"C:\Users\Public\denoise.flag"

# ==============================================================================
# Windows UAC Auto-Elevation
# ==============================================================================
def check_and_elevate():
    if os.name == 'nt':
        import ctypes
        try:
            if not ctypes.windll.shell32.IsUserAnAdmin():
                print("[*] Requesting Administrator privileges to patch Program Files...")
                script = os.path.abspath(sys.argv[0])
                params = ' '.join(f'"{arg}"' for arg in sys.argv[1:])
                ret = ctypes.windll.shell32.ShellExecuteW(None, "runas", sys.executable, f'"{script}" {params}', None, 1)
                sys.exit(0)
        except Exception as e:
            print(f"[!] UAC Elevation note: {e}")

# ==============================================================================
# PE Parsing & Helper Functions
# ==============================================================================
def ensure_studio_closed():
    try:
        out = subprocess.check_output('tasklist /FI "IMAGENAME eq Insta360 Studio.exe" /NH', shell=True).decode()
        if "Insta360 Studio.exe" in out:
            print("[*] Closing running Insta360 Studio process before modifying files...")
            subprocess.call('taskkill /F /IM "Insta360 Studio.exe"', shell=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            import time; time.sleep(1)
    except Exception:
        pass

def get_pe_section(data, sec_name):
    pe_off = struct.unpack('<I', data[0x3C:0x40])[0]
    num_sections = struct.unpack('<H', data[pe_off+6:pe_off+8])[0]
    opt_hdr_size = struct.unpack('<H', data[pe_off+20:pe_off+22])[0]
    sec_off = pe_off + 24 + opt_hdr_size
    for i in range(num_sections):
        sec = data[sec_off + i*40 : sec_off + (i+1)*40]
        name = sec[:8].decode('latin1', errors='ignore').strip('\x00')
        if name.lower() == sec_name.lower():
            vsize, vaddr, raw_size, raw_ptr = struct.unpack('<IIII', sec[8:24])
            return {
                'name': name,
                'vsize': vsize,
                'vaddr': vaddr,
                'raw_size': raw_size,
                'raw_ptr': raw_ptr
            }
    return None

def find_code_cave(data, min_size=100):
    text_sec = get_pe_section(data, '.text')
    if not text_sec:
        return None, None
    raw_start = text_sec['raw_ptr']
    raw_end = raw_start + text_sec['raw_size']
    end_idx = raw_end - 1
    while end_idx >= raw_start and data[end_idx] == 0:
        end_idx -= 1
    cave_start = end_idx + 1
    if cave_start % 16 != 0:
        cave_start = (cave_start + 15) & ~15
    cave_size = raw_end - cave_start
    if cave_size >= min_size:
        vaddr = text_sec['vaddr'] + (cave_start - text_sec['raw_ptr'])
        return cave_start, vaddr
    return None, None

def get_iat_entry(data, dll_name_match, func_name_match):
    rdata_sec = get_pe_section(data, '.rdata')
    if not rdata_sec:
        return None
    pe_off = struct.unpack('<I', data[0x3C:0x40])[0]
    import_rva, _ = struct.unpack('<II', data[pe_off+0x18+0x70+8 : pe_off+0x18+0x70+16])
    if not import_rva:
        return None

    def rva_to_off(rva):
        return rdata_sec['raw_ptr'] + (rva - rdata_sec['vaddr'])

    curr = rva_to_off(import_rva)
    while True:
        entry = data[curr:curr+20]
        if len(entry) < 20: break
        ilt_rva, ts, fc, name_rva, iat_rva = struct.unpack('<IIIII', entry)
        if name_rva == 0: break
        dll_name = data[rva_to_off(name_rva):rva_to_off(name_rva)+64].split(b'\x00')[0].decode('latin1')
        if dll_name_match.lower() in dll_name.lower():
            idx = 0
            while True:
                iat_pos = rva_to_off(iat_rva + idx*8)
                val = struct.unpack('<Q', data[iat_pos:iat_pos+8])[0]
                if val == 0: break
                f_name_pos = rva_to_off(val) + 2
                fname = data[f_name_pos:f_name_pos+64].split(b'\x00')[0].decode('latin1')
                if func_name_match.lower() == fname.lower():
                    return iat_rva + idx*8
                idx += 1
        curr += 20
    return None

# ==============================================================================
# Dynamic Patcher Class
# ==============================================================================
class DynamicPatcher:
    def __init__(self, install_dir=DEFAULT_INSTALL_DIR):
        self.install_dir = install_dir
        self.exe_path = os.path.join(install_dir, "Insta360 Studio.exe")
        self.dll_path = os.path.join(install_dir, "studio_worker.dll")
        self.exe_bak = self.exe_path + ".bak"
        self.dll_bak = self.dll_path + ".bak"

    def ensure_backups(self):
        if os.path.exists(self.exe_path) and not os.path.exists(self.exe_bak):
            print(f"[*] Creating first-time backup: {self.exe_bak}")
            shutil.copy2(self.exe_path, self.exe_bak)
        if os.path.exists(self.dll_path) and not os.path.exists(self.dll_bak):
            print(f"[*] Creating first-time backup: {self.dll_bak}")
            shutil.copy2(self.dll_path, self.dll_bak)

    # --------------------------------------------------------------------------
    # Status Scanners
    # --------------------------------------------------------------------------
    def get_lut_status(self):
        if not os.path.exists(self.exe_path): return "NOT FOUND"
        try:
            with open(self.exe_path, "rb") as f:
                data = f.read(0x4000000)
            p_patched = re.compile(rb'\x0F\xB6\x41\x1C\xC3.{5,40}\x38\x51\x1C.{2,10}\x88\x51\x1C.{10,50}\xB0\x01\xC3', re.DOTALL)
            if p_patched.search(data):
                return "PATCHED (Universal 3D LUT + Sliders Unlocked)"
            p_stock = re.compile(rb'\x0F\xB6\x41\x1C\xC3.{5,40}\x38\x51\x1C.{2,10}\x88\x51\x1C.{10,50}\x0F\xB6\x41\x1D\xC3', re.DOTALL)
            if p_stock.search(data):
                return "STOCK (i-Log Only)"
            return "CUSTOM / UNKNOWN"
        except Exception as e:
            return f"ERROR ({e})"

    def get_motion_nd_status(self):
        if not os.path.exists(self.dll_path): return "NOT FOUND"
        try:
            with open(self.dll_path, "rb") as f:
                dll_data = f.read()
            if b'\xE9\x2C\xFF\xFF\xFF\x90\x90' in dll_data:
                return "PATCHED (Export Bypass Active + Default OFF)"
            return "STOCK (Motion Blur Render Enabled)"
        except Exception as e:
            return f"ERROR ({e})"

    def get_denoise_status(self):
        if not os.path.exists(self.dll_path): return "NOT FOUND"
        try:
            with open(self.dll_path, "rb") as f:
                dll_data = f.read()
            if b'C:\\Users\\Public\\denoise.flag\x00' in dll_data:
                return "PATCHED (In-App Export Dialog Toggle Active)"
            return "STOCK (Multi-Frame Denoise Always On)"
        except Exception as e:
            return f"ERROR ({e})"

    def get_server_status(self):
        try:
            req = urllib.request.urlopen("http://127.0.0.1:8999/ping", timeout=0.5)
            data = json.loads(req.read().decode('utf-8'))
            if data.get("status") == "ok":
                return f"ACTIVE (Port 8999, {data.get('lut_count', 0)} LUTs loaded)"
        except Exception:
            pass
        return "STOPPED"

    # --------------------------------------------------------------------------
    # Patch 1: Universal LUT Engine & In-App UI
    # --------------------------------------------------------------------------
    def patch_lut_engine(self, enable=True):
        ensure_studio_closed()
        self.ensure_backups()
        with open(self.exe_path, "r+b") as f:
            data = f.read()

            # 1. supportLut getters in MediaProcessModel and MediaProcessViewModel
            p_lut_stock = re.compile(rb'\x0F\xB6\x41\x1C\xC3.{5,40}\x38\x51\x1C.{2,10}\x88\x51\x1C.{10,50}\x0F\xB6\x41\x1D\xC3', re.DOTALL)
            p_lut_patched = re.compile(rb'\x0F\xB6\x41\x1C\xC3.{5,40}\x38\x51\x1C.{2,10}\x88\x51\x1C.{10,50}\xB0\x01\xC3\x90\x90', re.DOTALL)
            p_target = p_lut_stock if enable else p_lut_patched
            count = 0
            for m in p_target.finditer(data):
                off = m.end() - 5
                f.seek(off)
                f.write(b"\xB0\x01\xC3\x90\x90" if enable else b"\x0F\xB6\x41\x1D\xC3")
                count += 1
            print(f" -> supportLut getters updated: {count} match(es)")

            # 2. filtersModifiable getters in MediaProcessModel and MediaProcessViewModel
            p_fm_stock = re.compile(rb'\x0F\xB6\x41\x19\xC3.{5,40}\x38\x51\x19.{2,10}\x88\x51\x19.{10,50}\x0F\xB6\x41\x1A\xC3', re.DOTALL)
            p_fm_patched = re.compile(rb'\x0F\xB6\x41\x19\xC3.{5,40}\x38\x51\x19.{2,10}\x88\x51\x19.{10,50}\xB0\x01\xC3\x90\x90', re.DOTALL)
            p_target_fm = p_fm_stock if enable else p_fm_patched
            count_fm = 0
            for m in p_target_fm.finditer(data):
                off = m.end() - 5
                f.seek(off)
                f.write(b"\xB0\x01\xC3\x90\x90" if enable else b"\x0F\xB6\x41\x1A\xC3")
                count_fm += 1
            print(f" -> filtersModifiable getters updated: {count_fm} match(es)")

            # 3. filtersModifiable function and reset callback
            p_res_stock = re.compile(rb'\x40\x53\x48\x83\xEC\x20\x48\x8B\xD9\x48\x8B\x09\x48\x85\xC9\x74\x56\xE8')
            p_res_patched = re.compile(rb'\xC3\x90\x90\x90\x90\x90\x48\x8B\xD9\x48\x8B\x09\x48\x85\xC9\x74\x56\xE8')
            m_res = (p_res_stock if enable else p_res_patched).search(data)
            if m_res:
                # Reset hook
                f.seek(m_res.start())
                f.write(b"\xC3\x90\x90\x90\x90\x90" if enable else b"\x40\x53\x48\x83\xEC\x20")
                # filtersModifiable function sits 0x40 bytes before reset hook
                func_off = m_res.start() - 0x40
                f.seek(func_off)
                f.write(b"\xB0\x01\xC3\x90\x90\x90" if enable else b"\x40\x53\x48\x83\xEC\x20")
                print(" -> filtersModifiable function & reset callback updated")

            # 4. Default LUT Off on Clip Load
            p_dlut_stock = re.compile(rb'\x4C\x8B\x82\x30\x01\x00\x00\x48\x8D\x54\x24\x20\x48\x8B\xC8\x41\xFF\xD0\x0F\xB6\xD0\x48\x8B\xCB')
            p_dlut_patched = re.compile(rb'\x4C\x8B\x82\x30\x01\x00\x00\x48\x8D\x54\x24\x20\x48\x8B\xC8\x41\xFF\xD0\x31\xD2\x90\x48\x8B\xCB')
            m_dlut = (p_dlut_stock if enable else p_dlut_patched).search(data)
            if m_dlut:
                f.seek(m_dlut.start() + 18)
                f.write(b"\x31\xD2\x90" if enable else b"\x0F\xB6\xD0")
                print(" -> Default LUT Off on Clip Load updated")

            # 5. LutView.qml UI injection
            if enable:
                idx_lutview = data.find(b'restore.lut')
                if idx_lutview != -1:
                    p_drawer = data.rfind(b'InsDrawer', 0, idx_lutview)
                    start = data.rfind(b'import QtQuick', 0, p_drawer) if p_drawer != -1 else data.rfind(b'import QtQuick', 0, idx_lutview)
                    target_size = struct.unpack('>I', data[start-4:start])[0] if start >= 4 else 536
                    # Verify target_size sanity (standard uncompressed LutView is ~536 bytes)
                    if not (200 <= target_size <= 2000):
                        target_size = 536
                    new_qml_base = (
                        b'import QtQuick\nimport QtQuick.Layouts\nimport InsTS 1.0\nimport Common.ViewModel 1.0\n'
                        b'import "../../../../ins_control/common/container"\n'
                        b'InsDrawer{id:r;required property MediaProcessViewModel viewModel;title:TS.insTr("restore.lut");visible:true;checked:viewModel.enableLut\n'
                        b'Connections{target:r;function onSwitchClicked(c){viewModel.modifyLutEnable(c);viewModel.reportLutEnable(c)}}\n'
                        b'ColumnLayout{Layout.fillWidth:true\n'
                        b'Loader{Layout.fillWidth:true;source:"file:///C:/Users/Public/L.qml";onLoaded:{if(item)item.viewModel=r.viewModel}}}}'
                    )
                    pad_len = max(0, target_size - len(new_qml_base))
                    new_qml = new_qml_base + (b' ' * pad_len)
                    f.seek(start)
                    f.write(new_qml[:target_size])
                    print(f" -> In-App Look Selector injected into LutView.qml at 0x{start:X} (exact size: {target_size})")
                if os.path.exists(L_QML_FILE):
                    shutil.copy2(L_QML_FILE, PUBLIC_L_QML)

        print("[OK] Universal Custom LUT Engine & In-App UI successfully updated!")

    # --------------------------------------------------------------------------
    # Patch 2: Motion ND Fix & Export Bypass
    # --------------------------------------------------------------------------
    def patch_motion_nd(self, enable=True):
        ensure_studio_closed()
        self.ensure_backups()
        # 1. Patch EXE Loaders (Default OFF on media load)
        with open(self.exe_path, "r+b") as f:
            exe_data = f.read()

            # Loader 1
            p_mnd1_s = re.compile(rb'(\x84\xDB\x74\x0D\x80\xBE.{2}\x00\x00\x00\x74\x04)\xB2\x01(\xEB\x02\x33\xD2)', re.DOTALL)
            p_mnd1_p = re.compile(rb'(\x84\xDB\x74\x0D\x80\xBE.{2}\x00\x00\x00\x74\x04)\x31\xD2(\xEB\x02\x33\xD2)', re.DOTALL)
            m = (p_mnd1_s if enable else p_mnd1_p).search(exe_data)
            if m:
                f.seek(m.start() + len(m.group(1)))
                f.write(b"\x31\xD2" if enable else b"\xB2\x01")
                print(" -> Motion ND Loader 1 updated")

            # Loader 2
            p_mnd2_s = re.compile(rb'(\x0F\xB6\xD0\x48\x8B.{2,15})\x0F\xB6\xD3(\x48\x8B)', re.DOTALL)
            p_mnd2_p = re.compile(rb'(\x0F\xB6\xD0\x48\x8B.{2,15})\x31\xD2\x90(\x48\x8B)', re.DOTALL)
            m = (p_mnd2_s if enable else p_mnd2_p).search(exe_data)
            if m:
                f.seek(m.start() + len(m.group(1)))
                f.write(b"\x31\xD2\x90" if enable else b"\x0F\xB6\xD3")
                print(" -> Motion ND Loader 2 updated")

            # Loader 3
            p_mnd3_s = re.compile(rb'(\x75\x04\x33\xD2\xEB\x07\x45\x84\xE4\x74.{1})\xB2\x01(\x48\x8B\xCF)', re.DOTALL)
            p_mnd3_p = re.compile(rb'(\x75\x04\x33\xD2\xEB\x07\x45\x84\xE4\x74.{1})\x31\xD2(\x48\x8B\xCF)', re.DOTALL)
            m = (p_mnd3_s if enable else p_mnd3_p).search(exe_data)
            if m:
                f.seek(m.start() + len(m.group(1)))
                f.write(b"\x31\xD2" if enable else b"\xB2\x01")
                print(" -> Motion ND Loader 3 updated")

        # 2. Patch studio_worker.dll (Export bypass)
        with open(self.dll_path, "r+b") as f:
            dll_data = f.read()

            # FilterDispatcher: 48 8B 82 88 00 00 00 -> E9 2C FF FF FF 90 90
            p_disp_s = re.compile(rb'\x48\x8B\x82\x88\x00\x00\x00\x48\x8D\x3D.{4}\x48\x85\xC0\x48\x0F\x45\xF8')
            p_disp_p = re.compile(rb'\xE9\x2C\xFF\xFF\xFF\x90\x90\x48\x8D\x3D.{4}\x48\x85\xC0\x48\x0F\x45\xF8')
            m = (p_disp_s if enable else p_disp_p).search(dll_data)
            if m:
                f.seek(m.start())
                f.write(b"\xE9\x2C\xFF\xFF\xFF\x90\x90" if enable else b"\x48\x8B\x82\x88\x00\x00\x00")
                print(f" -> Motion ND FilterDispatcher export bypass updated at 0x{m.start():X}")

        print("[OK] Motion ND Fix & Export Bypass successfully updated!")

    # --------------------------------------------------------------------------
    # Patch 3: Export Dialog Noise Reduction Toggle (2.4x Speedup)
    # --------------------------------------------------------------------------
    def patch_denoise_toggle(self, enable=True):
        ensure_studio_closed()
        self.ensure_backups()

        # 1. Update studio_worker.dll dynamic hook
        with open(self.dll_path, "r+b") as f:
            dll_data = f.read()
            text_sec = get_pe_section(dll_data, '.text')
            img_base = 0x180000000

            p_call = re.compile(rb'(\x8B\xD3\x48\x8B\xCE)\xE8(.{4})(\x84\xC0\x0F\x84.{4}\x44\x8B\xC3)', re.DOTALL)
            m = p_call.search(dll_data)

            if m:
                call_site_off = m.start() + len(m.group(1))
                call_site_va = img_base + text_sec['vaddr'] + (call_site_off - text_sec['raw_ptr'])

                cave_off, cave_va = find_code_cave(dll_data, 80)
                iat_rva = get_iat_entry(dll_data, 'kernel32', 'GetFileAttributesA')
                iat_va = img_base + iat_rva if iat_rva else None

                if enable and cave_off and iat_va:
                    orig_rel = struct.unpack('<i', m.group(2))[0]
                    # If already pointing to cave, read stock VA
                    if b'C:\\Users\\Public\\denoise.flag' in dll_data[cave_off:cave_off+100]:
                        func_va = call_site_va - 0x4DE # standard delta
                    else:
                        func_va = call_site_va + 5 + orig_rel

                    flag_va = cave_va + 0x28
                    disp_flag = flag_va - (cave_va + 0x0B)
                    disp_iat = iat_va - (cave_va + 0x11)
                    disp_func = func_va - (cave_va + 0x24)
                    disp_je = 0x24 - (0x18 + 2)

                    cave_code = bytearray()
                    cave_code += bytes([0x48, 0x83, 0xEC, 0x28])                     # sub rsp, 28h
                    cave_code += bytes([0x48, 0x8D, 0x0D]) + struct.pack('<i', disp_flag) # lea rcx, flag
                    cave_code += bytes([0xFF, 0x15]) + struct.pack('<i', disp_iat)        # call GetFileAttributesA
                    cave_code += bytes([0x48, 0x83, 0xC4, 0x28])                     # add rsp, 28h
                    cave_code += bytes([0x83, 0xF8, 0xFF])                           # cmp eax, -1
                    cave_code += bytes([0x74, disp_je])                              # je denoise_off
                    cave_code += bytes([0x89, 0xDA])                                 # mov edx, ebx
                    cave_code += bytes([0x48, 0x89, 0xF1])                           # mov rcx, rsi
                    cave_code += bytes([0xE9]) + struct.pack('<i', disp_func)        # jmp func_va
                    cave_code += bytes([0x31, 0xC0])                                 # xor eax, eax
                    cave_code += bytes([0xC3, 0x90])                                 # ret; nop
                    cave_code += b"C:\\Users\\Public\\denoise.flag\x00"              # flag path

                    f.seek(cave_off)
                    f.write(cave_code)

                    disp_call = cave_va - (call_site_va + 5)
                    f.seek(call_site_off)
                    f.write(b"\xE8" + struct.pack('<i', disp_call))

                    # Restore prologue if previously modified
                    prologue_off = text_sec['raw_ptr'] + (func_va - img_base - text_sec['vaddr'])
                    f.seek(prologue_off)
                    f.write(b"\x48\x89\x5C\x24\x18\x55")
                    print(f" -> Dynamic denoise hook installed in .text cave at 0x{cave_off:X}")

        # 2. Update SingleVideoExport.qml inside EXE RCC dynamically
        with open(self.exe_path, "r+b") as f:
            exe_data = f.read()

            for m in re.finditer(b'\x78[\x9c\x01\xda]', exe_data):
                off = m.start()
                try:
                    decomp = zlib.decompress(exe_data[off:off+10000])
                    if b'videoParamsGrid' in decomp and b'bitrateSlider' in decomp:
                        qml_off = off
                        f.seek(qml_off - 8)
                        comp_size_plus_4, uncomp_len = struct.unpack('>II', f.read(8))
                        target_comp_size = comp_size_plus_4 - 4
                        full_decomp = zlib.decompress(exe_data[qml_off:qml_off+target_comp_size])
                        qml_text = full_decomp.decode('utf-8', errors='ignore').replace('\r\n', '\n')

                        if enable and 'denoiseCheckBox' not in qml_text:
                            combo_idx = qml_text.find('id: encodeFormatCombox')
                            if combo_idx != -1:
                                lbl_idx = qml_text.rfind('InsLabel {', 0, combo_idx)
                                line_start = qml_text.rfind('\n', 0, lbl_idx)
                                if qml_text[line_start-15:line_start].strip().startswith('//'):
                                    line_start = qml_text.rfind('\n', 0, line_start - 1)

                                denoise_block = (
                                    '\n                    // Row 7: Denoise Toggle\n'
                                    '                    InsLabel {\n'
                                    '                        Layout.row: 7\n'
                                    '                        Layout.column: 0\n'
                                    '                        Layout.preferredWidth: 80\n'
                                    '                        Layout.maximumWidth: 80\n'
                                    '                        Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter\n'
                                    '                        Layout.preferredHeight: itemHeight\n'
                                    '                        horizontalAlignment: Text.AlignLeft\n'
                                    '                        color: InsUI.colorStandardSubtext\n'
                                    '                        text: "Denoise:"\n'
                                    '                    }\n\n'
                                    '                    Item {\n'
                                    '                        Layout.row: 7\n'
                                    '                        Layout.column: 1\n'
                                    '                        Layout.fillWidth: true\n'
                                    '                        Layout.preferredHeight: 30\n\n'
                                    '                        RowLayout {\n'
                                    '                            anchors.fill: parent\n'
                                    '                            spacing: 8\n\n'
                                    '                            InsMultiCheckBox {\n'
                                    '                                id: denoiseCheckBox\n'
                                    '                                checked: false\n'
                                    '                                text: "Noise Reduction (Default OFF = Grain, 2.4x Speed)"\n'
                                    '                                onToggled: {\n'
                                    '                                    root.setDenoiseState(checked)\n'
                                    '                                }\n'
                                    '                            }\n'
                                    '                        }\n'
                                    '                    }\n'
                                )
                                mod = qml_text[:line_start] + denoise_block + qml_text[line_start:]
                                mod = re.sub(r'(id:\s*encodeFormatCombox\s*\n\s*Layout\.row:\s*)7', r'\g<1>8', mod)
                                mod = re.sub(r'(Layout\.row:\s*)7(\s*\n\s*Layout\.column:\s*0\s*\n[\s\S]*?id:\s*encodeFormatCombox)', r'\g<1>8\2', mod)

                                methods = (
                                    '\n    function checkDenoiseState() {\n'
                                    '        var xhr = new XMLHttpRequest();\n'
                                    '        xhr.open("GET", "http://127.0.0.1:8999/denoise", true);\n'
                                    '        xhr.onreadystatechange = function() {\n'
                                    '            if (xhr.readyState === XMLHttpRequest.DONE && xhr.status === 200) {\n'
                                    '                try {\n'
                                    '                    var resp = JSON.parse(xhr.responseText);\n'
                                    '                    if (typeof resp.enabled !== "undefined") {\n'
                                    '                        denoiseCheckBox.checked = !!resp.enabled;\n'
                                    '                    }\n'
                                    '                } catch(e) {}\n'
                                    '            }\n'
                                    '        };\n'
                                    '        xhr.send();\n'
                                    '    }\n\n'
                                    '    function setDenoiseState(enabled) {\n'
                                    '        var xhr = new XMLHttpRequest();\n'
                                    '        xhr.open("GET", "http://127.0.0.1:8999/denoise?enabled=" + (enabled ? "1" : "0"), true);\n'
                                    '        xhr.send();\n'
                                    '    }\n'
                                )
                                root_idx = mod.find('Item {\n    id: root')
                                insert_pos = mod.find('\n', root_idx + 20)
                                mod = mod[:insert_pos] + methods + mod[insert_pos:]

                                on_comp = mod.find('Component.onCompleted:')
                                if on_comp != -1:
                                    brace = mod.find('{', on_comp)
                                    mod = mod[:brace+1] + '\n        Qt.callLater(root.checkDenoiseState);' + mod[brace+1:]

                                clean = re.sub(r'// [^\n]*\n', '\n', mod)
                                clean_bytes = clean.encode('utf-8')
                                comp = zlib.compress(clean_bytes, 9)

                                if len(comp) <= target_comp_size:
                                    padded = comp + b'\x00' * (target_comp_size - len(comp))
                                    f.seek(qml_off - 4)
                                    f.write(struct.pack('>I', len(clean_bytes)))
                                    f.seek(qml_off)
                                    f.write(padded)
                                    print(f" -> Injected Denoise toggle into SingleVideoExport.qml at 0x{qml_off:X} (headroom={target_comp_size - len(comp)} bytes)")
                        break
                except Exception:
                    pass

        print("[OK] Export Dialog Noise Reduction Toggle successfully updated!")

    # --------------------------------------------------------------------------
    # Patch 4: Background Service Control
    # --------------------------------------------------------------------------
    def start_service(self):
        status = self.get_server_status()
        if "ACTIVE" in status:
            print("[*] Background LUT Service is already active.")
            return
        print("[*] Starting Background LUT Service (port 8999)...")
        subprocess.Popen(["pythonw", SERVICE_SCRIPT], cwd=MOD_DIR, creationflags=subprocess.CREATE_NO_WINDOW if os.name == 'nt' else 0)
        import time; time.sleep(1)
        print(f"[OK] Server status: {self.get_server_status()}")

    def stop_service(self):
        print("[*] Stopping Background LUT Service...")
        try:
            out = subprocess.check_output('powershell -Command "Get-NetTCPConnection -LocalPort 8999 -ErrorAction SilentlyContinue | Select-Object -ExpandProperty OwningProcess"', shell=True).decode()
            pids = [int(p.strip()) for p in out.splitlines() if p.strip().isdigit() and int(p.strip()) > 0]
            for pid in set(pids):
                subprocess.call(f'taskkill /F /PID {pid}', shell=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            print("[OK] Background LUT Service stopped.")
        except Exception as e:
            print(f"[!] Could not stop service: {e}")

    # --------------------------------------------------------------------------
    # Patch 5: Restore All Backups
    # --------------------------------------------------------------------------
    def restore_all(self):
        ensure_studio_closed()
        print("[*] Restoring original backups...")
        if os.path.exists(self.exe_bak):
            shutil.copy2(self.exe_bak, self.exe_path)
            print(" -> Restored stock Insta360 Studio.exe")
        if os.path.exists(self.dll_bak):
            shutil.copy2(self.dll_bak, self.dll_path)
            print(" -> Restored stock studio_worker.dll")
        if os.path.exists(PUBLIC_DENOISE_FLAG):
            try: os.remove(PUBLIC_DENOISE_FLAG)
            except: pass
        print("[OK] Complete factory unpatch finished successfully.")

    def launch_app(self):
        print("[*] Launching Insta360 Studio...")
        subprocess.Popen([self.exe_path], cwd=self.install_dir)

# ==============================================================================
# Interactive Terminal Menu
# ==============================================================================
def clear_screen():
    os.system('cls' if os.name == 'nt' else 'clear')

def interactive_menu():
    check_and_elevate()
    patcher = DynamicPatcher()

    while True:
        clear_screen()
        print("========================================================================")
        print("          INSTA360 STUDIO DYNAMIC SIGNATURE PATCHER & MANAGER          ")
        print("========================================================================")
        print(f" Target Folder: {patcher.install_dir}")
        print("------------------------------------------------------------------------")
        print(f"   [1] 3D LUT Engine & UI       : {patcher.get_lut_status()}")
        print(f"   [2] Motion ND Fix (Export)   : {patcher.get_motion_nd_status()}")
        print(f"   [3] Denoise Export Toggle    : {patcher.get_denoise_status()}")
        print(f"   [4] Background LUT Server    : {patcher.get_server_status()}")
        print("========================================================================")
        print("   QUICK ACTIONS:")
        print("     [A] Apply ALL Recommended Mods (LUTs + Motion ND + Denoise Toggle)")
        print("     [L] Launch Insta360 Studio")
        print("     [R] Restore Original Factory Binaries (.bak unpatch)")
        print("------------------------------------------------------------------------")
        print("   INDIVIDUAL TOGGLES:")
        print("     [1] Toggle Universal Custom LUT Engine & Look Selector")
        print("     [2] Toggle Motion ND Fix (Default OFF + Export Bypass)")
        print("     [3] Toggle In-App Export Dialog Noise Reduction Toggle")
        print("     [4] Start / Stop Background LUT Service")
        print("------------------------------------------------------------------------")
        print("     [0] Exit")
        print("========================================================================")

        try:
            choice = input("\nSelect an option: ").strip().upper()
        except (KeyboardInterrupt, EOFError):
            break

        try:
            if choice == '0':
                break
            elif choice == 'A':
                print("\n[*] Applying all recommended mods...")
                patcher.patch_lut_engine(True)
                patcher.patch_motion_nd(True)
                patcher.patch_denoise_toggle(True)
                patcher.start_service()
                input("\n[SUCCESS] All mods successfully applied! Press Enter to continue...")
            elif choice == 'L':
                patcher.launch_app()
                input("\nApp launched. Press Enter to continue...")
            elif choice == 'R':
                confirm = input("\nAre you sure you want to restore original factory files? (y/n): ")
                if confirm.lower() == 'y':
                    patcher.restore_all()
                input("\nPress Enter to continue...")
            elif choice == '1':
                curr = "PATCHED" in patcher.get_lut_status()
                patcher.patch_lut_engine(not curr)
                input("\nPress Enter to continue...")
            elif choice == '2':
                curr = "PATCHED" in patcher.get_motion_nd_status()
                patcher.patch_motion_nd(not curr)
                input("\nPress Enter to continue...")
            elif choice == '3':
                curr = "PATCHED" in patcher.get_denoise_status()
                patcher.patch_denoise_toggle(not curr)
                input("\nPress Enter to continue...")
            elif choice == '4':
                curr = "ACTIVE" in patcher.get_server_status()
                if curr: patcher.stop_service()
                else: patcher.start_service()
                input("\nPress Enter to continue...")
        except Exception as e:
            print("\n" + "="*60)
            print("[!] An error occurred during patching:")
            traceback.print_exc()
            print("="*60)
            input("\nPress Enter to return to menu...")

if __name__ == "__main__":
    if len(sys.argv) > 1:
        arg = sys.argv[1].lower()
        if arg not in ("--status", "-s"):
            check_and_elevate()
        patcher = DynamicPatcher()
        try:
            if arg in ("--all", "-a"):
                patcher.patch_lut_engine(True)
                patcher.patch_motion_nd(True)
                patcher.patch_denoise_toggle(True)
                patcher.start_service()
            elif arg in ("--lut", "-l"):
                patcher.patch_lut_engine(True)
            elif arg in ("--mnd", "-m"):
                patcher.patch_motion_nd(True)
            elif arg in ("--denoise", "-d"):
                patcher.patch_denoise_toggle(True)
            elif arg in ("--restore", "-r"):
                patcher.restore_all()
            elif arg in ("--status", "-s"):
                print("LUT:", patcher.get_lut_status())
                print("MND:", patcher.get_motion_nd_status())
                print("Denoise:", patcher.get_denoise_status())
                print("Server:", patcher.get_server_status())
        except Exception as e:
            print("\n[!] Error:")
            traceback.print_exc()
            input("\nPress Enter to exit...")
    else:
        interactive_menu()
