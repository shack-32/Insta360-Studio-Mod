import os
import sys
import struct
import zlib
import re
import shutil

MOD_DIR = os.path.dirname(os.path.abspath(__file__))
INSTALL_DIR = r"C:\Program Files\Insta360 Studio"

EXE_TARGET = os.path.join(INSTALL_DIR, "Insta360 Studio.exe")
EXE_MOD = os.path.join(MOD_DIR, "Insta360 Studio_lutmod.exe")
EXE_STOCK = os.path.join(MOD_DIR, "Insta360 Studio_stock.exe")

DLL_TARGET = os.path.join(INSTALL_DIR, "studio_worker.dll")
DLL_MOD = os.path.join(MOD_DIR, "studio_worker_nodenoise.dll")
DLL_STOCK = os.path.join(MOD_DIR, "studio_worker_stock.dll")

from build_patches import get_qml_payload, get_worker_patch

def patch_exe(file_path):
    print(f"Patching EXE: {file_path}")
    uncomp_len, qml_payload = get_qml_payload()
    with open(file_path, "r+b") as f:
        # 1. Update uncompressed length at 0x6B1AF61
        f.seek(0x6B1AF61)
        f.write(struct.pack('>I', uncomp_len))
        # 2. Write compressed QML at 0x6B1AF65
        f.seek(0x6B1AF65)
        f.write(qml_payload)
    print(f" -> Successfully patched QML export dialog into {file_path} (uncompressed={uncomp_len}, compressed={len(qml_payload)})")

def patch_worker_dll(file_path):
    print(f"Patching Worker DLL: {file_path}")
    cave_code, call_patch, prologue = get_worker_patch()
    with open(file_path, "r+b") as f:
        # 1. Restore prologue at 0x31CE730
        f.seek(0x31CE730)
        f.write(prologue)
        # 2. Patch call site at 0x31CEC0E
        f.seek(0x31CEC0E)
        f.write(call_patch)
        # 3. Write cave helper at 0x6A6E750
        f.seek(0x6A6E750)
        f.write(cave_code)
    print(f" -> Successfully installed dynamic denoise hook into {file_path}")

def main():
    # 1. Patch local modded EXE and DLL
    patch_exe(EXE_MOD)
    patch_worker_dll(DLL_MOD)

    # 2. Patch installed target EXE and DLL
    patch_exe(EXE_TARGET)
    patch_worker_dll(DLL_TARGET)

    print("\nAll binaries successfully updated with Export Dialog Denoise Toggle!")

if __name__ == "__main__":
    main()
