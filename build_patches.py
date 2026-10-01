import os
import sys
import struct
import zlib
import re
import capstone

# Paths
MOD_DIR = os.path.dirname(os.path.abspath(__file__))
INSTALL_DIR = r"C:\Program Files\Insta360 Studio"

EXE_TARGET = os.path.join(INSTALL_DIR, "Insta360 Studio.exe")
EXE_MOD = os.path.join(MOD_DIR, "Insta360 Studio_lutmod.exe")
EXE_STOCK = os.path.join(MOD_DIR, "Insta360 Studio_stock.exe")

DLL_TARGET = os.path.join(INSTALL_DIR, "studio_worker.dll")
DLL_MOD = os.path.join(MOD_DIR, "studio_worker_nodenoise.dll")
DLL_STOCK = os.path.join(MOD_DIR, "studio_worker_stock.dll")

QML_PATH = os.path.join(MOD_DIR, "SingleVideoExport.qml")

# ---------------------------------------------------------
# 1. Build Modified QML Payload
# ---------------------------------------------------------
def get_qml_payload():
    with open(QML_PATH, "r", encoding="utf-8") as f:
        text = f.read()

    old_encoding = (
        "                    // Row 7: \u7f16\u7801\u683c\u5f0f\uff08\u652f\u6301\u9884\u8bbe\uff0c\u5728\u6df1\u8272\u77e9\u5f62\u5185\uff09\n"
        "                    InsLabel {\n"
        "                        Layout.row: 7"
    )

    new_section = (
        "                    // Row 7: Denoise Toggle\n"
        "                    InsLabel {\n"
        "                        Layout.row: 7\n"
        "                        Layout.column: 0\n"
        "                        Layout.preferredWidth: 80\n"
        "                        Layout.maximumWidth: 80\n"
        "                        Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter\n"
        "                        Layout.preferredHeight: itemHeight\n"
        "                        horizontalAlignment: Text.AlignLeft\n"
        "                        color: InsUI.colorStandardSubtext\n"
        "                        text: \"Denoise:\"\n"
        "                    }\n\n"
        "                    Item {\n"
        "                        Layout.row: 7\n"
        "                        Layout.column: 1\n"
        "                        Layout.fillWidth: true\n"
        "                        Layout.preferredHeight: 30\n\n"
        "                        RowLayout {\n"
        "                            anchors.fill: parent\n"
        "                            spacing: 8\n\n"
        "                            InsMultiCheckBox {\n"
        "                                id: denoiseCheckBox\n"
        "                                checked: false\n"
        "                                text: \"Noise Reduction (Default OFF = Grain, 2.4x Speed)\"\n"
        "                                onToggled: {\n"
        "                                    root.setDenoiseState(checked)\n"
        "                                }\n"
        "                            }\n"
        "                        }\n"
        "                    }\n\n"
        "                    // Row 8: \u7f16\u7801\u683c\u5f0f\n"
        "                    InsLabel {\n"
        "                        Layout.row: 8"
    )

    if old_encoding not in text:
        raise ValueError("old_encoding not found in SingleVideoExport.qml")
    mod = text.replace(old_encoding, new_section, 1)

    old_combo = "                    InsComboBox {\n                        id: encodeFormatCombox\n                        Layout.row: 7"
    new_combo = "                    InsComboBox {\n                        id: encodeFormatCombox\n                        Layout.row: 8"
    if old_combo not in mod:
        raise ValueError("old_combo not found in SingleVideoExport.qml")
    mod = mod.replace(old_combo, new_combo, 1)

    root_anchor = "    function onDialogClosing() {"
    methods = (
        "    function checkDenoiseState() {\n"
        "        var xhr = new XMLHttpRequest();\n"
        "        xhr.open('GET', 'http://127.0.0.1:8999/denoise', true);\n"
        "        xhr.onreadystatechange = function() {\n"
        "            if (xhr.readyState === XMLHttpRequest.DONE && xhr.status === 200) {\n"
        "                try {\n"
        "                    var resp = JSON.parse(xhr.responseText);\n"
        "                    if (typeof resp.enabled !== 'undefined') {\n"
        "                        denoiseCheckBox.checked = !!resp.enabled;\n"
        "                    }\n"
        "                } catch(e) {}\n"
        "            }\n"
        "        };\n"
        "        xhr.send();\n"
        "    }\n\n"
        "    function setDenoiseState(enabled) {\n"
        "        var xhr = new XMLHttpRequest();\n"
        "        xhr.open('GET', 'http://127.0.0.1:8999/denoise?enabled=' + (enabled ? '1' : '0'), true);\n"
        "        xhr.send();\n"
        "    }\n\n"
        "    function onDialogClosing() {"
    )
    if root_anchor not in mod:
        raise ValueError("root_anchor not found in SingleVideoExport.qml")
    mod = mod.replace(root_anchor, methods, 1)

    on_comp_anchor = "Qt.callLater(syncAllComboBoxes)"
    new_on_comp = "Qt.callLater(syncAllComboBoxes)\n        Qt.callLater(root.checkDenoiseState)"
    if on_comp_anchor not in mod:
        raise ValueError("on_comp_anchor not found in SingleVideoExport.qml")
    mod = mod.replace(on_comp_anchor, new_on_comp, 1)

    clean = re.sub(r'// [^\n]*\n', '\n', mod)
    clean_bytes = clean.encode("utf-8")
    comp = zlib.compress(clean_bytes, 9)
    if len(comp) > 7281:
        raise ValueError(f"Compressed size {len(comp)} exceeds 7281 bytes!")
    padded = comp + b"\x00" * (7281 - len(comp))
    return len(clean_bytes), padded

# ---------------------------------------------------------
# 2. Build studio_worker Hook Code
# ---------------------------------------------------------
def get_worker_patch():
    cave_va = 0x186A6F150
    iat_va = 0x186A70570
    func_va = 0x1831CF130

    flag_str = b"C:\\Users\\Public\\denoise.flag\x00"
    flag_offset = 0x28
    flag_va = cave_va + flag_offset

    disp_flag = flag_va - (cave_va + 0x0B)
    disp_iat = iat_va - (cave_va + 0x11)
    disp_func = func_va - (cave_va + 0x24)
    disp_je = 0x24 - (0x18 + 2)

    cave_code = bytearray()
    cave_code += bytes([0x48, 0x83, 0xEC, 0x28])                     # 0x00: sub rsp, 0x28
    cave_code += bytes([0x48, 0x8D, 0x0D]) + struct.pack('<i', disp_flag) # 0x04: lea rcx, [rip + disp_flag]
    cave_code += bytes([0xFF, 0x15]) + struct.pack('<i', disp_iat)        # 0x0B: call qword ptr [rip + disp_iat]
    cave_code += bytes([0x48, 0x83, 0xC4, 0x28])                     # 0x11: add rsp, 0x28
    cave_code += bytes([0x83, 0xF8, 0xFF])                           # 0x15: cmp eax, -1
    cave_code += bytes([0x74, disp_je])                              # 0x18: je 0x24
    cave_code += bytes([0x89, 0xDA])                                 # 0x1A: mov edx, ebx
    cave_code += bytes([0x48, 0x89, 0xF1])                           # 0x1C: mov rcx, rsi
    cave_code += bytes([0xE9]) + struct.pack('<i', disp_func)        # 0x1F: jmp func_va
    cave_code += bytes([0x31, 0xC0])                                 # 0x24: xor eax, eax
    cave_code += bytes([0xC3])                                       # 0x26: ret
    cave_code += bytes([0x90])                                       # 0x27: nop
    cave_code += flag_str                                            # 0x28: string

    # Call site patch at file offset 0x31CEC0E (VA 0x1831CF60E)
    call_site_va = 0x1831CF60E
    disp_call = cave_va - (call_site_va + 5)
    call_patch = bytes([0xE8]) + struct.pack('<i', disp_call)

    # Function prologue restore at 0x31CE730 (VA 0x1831CF130)
    prologue_restore = bytes([0x48, 0x89, 0x5C, 0x24, 0x18, 0x55])

    return cave_code, call_patch, prologue_restore

# ---------------------------------------------------------
# Verification & Self-Test
# ---------------------------------------------------------
if __name__ == "__main__":
    uncomp_len, qml_payload = get_qml_payload()
    print(f"QML Payload: uncompressed={uncomp_len}, compressed_padded={len(qml_payload)}")
    assert len(qml_payload) == 7281

    cave_code, call_patch, prologue = get_worker_patch()
    print(f"Cave code size: {len(cave_code)} bytes, Call patch: {call_patch.hex()}, Prologue: {prologue.hex()}")

    md = capstone.Cs(capstone.CS_ARCH_X86, capstone.CS_MODE_64)
    print("\n--- Cave Helper Disassembly ---")
    for i in md.disasm(cave_code[:0x28], 0x186A6F150):
        print(f"0x{i.address:X}: {i.mnemonic} {i.op_str}")

    print("\n--- Call Site Disassembly ---")
    for i in md.disasm(call_patch, 0x1831CF60E):
        print(f"0x{i.address:X}: {i.mnemonic} {i.op_str}")
