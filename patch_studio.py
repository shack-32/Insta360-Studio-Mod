import os
import sys
import json
import shutil
import subprocess

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
DEFAULT_INSTALL_DIR = r"C:\Program Files\Insta360 Studio"
PATCHES_FILE = os.path.join(SCRIPT_DIR, "patches.json")

def stop_studio_processes():
    try:
        subprocess.run(["powershell", "-NoProfile", "-Command", "Get-Process -Name 'Insta360 Studio*', 'studio-exporter*', 'studio_worker*' -ErrorAction SilentlyContinue | Stop-Process -Force"], check=False)
    except Exception:
        pass

def load_patches():
    with open(PATCHES_FILE, "r", encoding="utf-8") as f:
        return json.load(f)

def apply_patches(install_dir=DEFAULT_INSTALL_DIR, reverse=False):
    stop_studio_processes()
    manifest = load_patches()
    patches = manifest["patches"]
    
    # Group patches by target file
    targets = {}
    for p in patches:
        targets.setdefault(p["target"], []).append(p)

    for target_name, file_patches in targets.items():
        file_path = os.path.join(install_dir, target_name)
        backup_path = file_path + ".stock"
        
        if not os.path.exists(file_path):
            print(f"[!] Target not found: {file_path}")
            continue

        try:
            with open(file_path, "rb") as f:
                data = bytearray(f.read())
        except PermissionError:
            print(f"[!] Permission denied reading {file_path}. Please run as Administrator.")
            continue

        print(f"\n[*] Processing {target_name} ({len(file_patches)} patches)...")
        modified = False

        for p in file_patches:
            offset = int(p["file_offset"], 16)
            orig_bytes = bytes.fromhex(p["original_hex"])
            patch_bytes = bytes.fromhex(p["patched_hex"])
            
            src_bytes = patch_bytes if reverse else orig_bytes
            dst_bytes = orig_bytes if reverse else patch_bytes
            action = "Reverting" if reverse else "Applying"

            curr_bytes = data[offset:offset+len(dst_bytes)]
            if curr_bytes == dst_bytes:
                print(f"  [OK] {p['name']} already {'reverted' if reverse else 'patched'}.")
            elif curr_bytes == src_bytes:
                # Ensure backup exists before first modification
                if not os.path.exists(backup_path):
                    local_stock = os.path.join(SCRIPT_DIR, target_name.replace(".exe", "_stock.exe").replace(".dll", "_stock.dll"))
                    if os.path.exists(local_stock):
                        try:
                            shutil.copyfile(local_stock, backup_path)
                            print(f"  [*] Created backup from local stock: {backup_path}")
                        except Exception:
                            pass
                    else:
                        try:
                            shutil.copyfile(file_path, backup_path)
                            print(f"  [*] Created backup: {backup_path}")
                        except Exception:
                            pass

                data[offset:offset+len(dst_bytes)] = dst_bytes
                modified = True
                print(f"  [+] {action} {p['name']} at {p['file_offset']}")
            else:
                print(f"  [!] Warning: Byte mismatch at {p['file_offset']}: expected {src_bytes.hex()[:16]}..., got {curr_bytes.hex()[:16]}...")

        if modified:
            try:
                with open(file_path, "wb") as f:
                    f.write(data)
                print(f"  [OK] Saved {file_path}")
            except PermissionError:
                print(f"[!] Access denied writing to {file_path}. Run this script as Administrator.")
        else:
            print(f"  [OK] All patches for {target_name} are already up-to-date.")

    action_label = "Uninstalled (Restored Stock)" if reverse else "Applied Successfully"
    print(f"\n[OK] Insta360 Studio Mods {action_label}!")

if __name__ == "__main__":
    reverse_mode = "--restore" in sys.argv or "--uninstall" in sys.argv
    target_dir = sys.argv[1] if len(sys.argv) > 1 and not sys.argv[1].startswith("--") else DEFAULT_INSTALL_DIR
    apply_patches(target_dir, reverse=reverse_mode)
