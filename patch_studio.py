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

        # Create backup if not already present
        if not os.path.exists(backup_path):
            print(f"[*] Creating backup: {backup_path}")
            shutil.copyfile(file_path, backup_path)

        with open(file_path, "rb") as f:
            data = bytearray(f.read())

        print(f"\n[*] Processing {target_name} ({len(file_patches)} patches)...")
        for p in file_patches:
            offset = int(p["file_offset"], 16)
            orig_bytes = bytes.fromhex(p["original_hex"])
            patch_bytes = bytes.fromhex(p["patched_hex"])
            
            src_bytes = patch_bytes if reverse else orig_bytes
            dst_bytes = orig_bytes if reverse else patch_bytes
            action = "Reverting" if reverse else "Applying"

            curr_bytes = data[offset:offset+len(dst_bytes)]
            if curr_bytes == dst_bytes:
                print(f"  [✓] {p['name']} already {'reverted' if reverse else 'patched'}.")
            elif curr_bytes == src_bytes:
                data[offset:offset+len(dst_bytes)] = dst_bytes
                print(f"  [+] {action} {p['name']} at {p['file_offset']} (VA {p.get('virtual_address', 'N/A')})")
            else:
                print(f"  [!] Warning: Byte mismatch at {p['file_offset']}: expected {src_bytes.hex()}, got {curr_bytes.hex()}")

        with open(file_path, "wb") as f:
            f.write(data)
        print(f"[✓] Saved {file_path}")

    # Ensure permissions
    try:
        subprocess.run(["icacls", install_dir, "/grant", "Users:(OI)(CI)F", "/T"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    except Exception:
        pass

    action_label = "Uninstalled (Restored Stock)" if reverse else "Applied Successfully"
    print(f"\n[OK] Insta360 Studio Mods {action_label}!")

if __name__ == "__main__":
    reverse_mode = "--restore" in sys.argv or "--uninstall" in sys.argv
    target_dir = sys.argv[1] if len(sys.argv) > 1 and not sys.argv[1].startswith("--") else DEFAULT_INSTALL_DIR
    apply_patches(target_dir, reverse=reverse_mode)
