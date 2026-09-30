import os
import shutil
import tkinter as tk
from tkinter import ttk, messagebox
import subprocess

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
CUSTOM_LUTS_DIR = os.path.join(SCRIPT_DIR, "Custom_LUTs")
STUDIO_ILOG_DIR = r"C:\Program Files\Insta360 Studio\data\i_log"

TARGET_LUTS = [
    "X5_I-Log_To_Rec.709_V1.0.cube",
    "AcePro2_I-Log_To_Rec.709_V1.0.cube",
    "X6_I-Log_To_Rec.709_V1.4.cube",
    "Luna_I-Log_to_Rec709.cube"
]

os.makedirs(CUSTOM_LUTS_DIR, exist_ok=True)

class LutSwitcherApp:
    def __init__(self, root):
        self.root = root
        self.root.title("Insta360 Live LUT Selector")
        self.root.geometry("420x260")
        self.root.resizable(False, False)
        self.root.configure(bg="#1e1e1e")

        # Stay on top by default for convenience next to Studio
        self.root.attributes("-topmost", True)

        # Style configuration
        self.style = ttk.Style()
        self.style.theme_use("clam")
        
        self.style.configure(".", background="#1e1e1e", foreground="#ffffff")
        self.style.configure("TLabel", background="#1e1e1e", foreground="#ffffff", font=("Segoe UI", 10))
        self.style.configure("Header.TLabel", font=("Segoe UI", 12, "bold"), foreground="#00d2ff")
        self.style.configure("Status.TLabel", font=("Segoe UI", 9), foreground="#a0a0a0")
        self.style.configure("Active.TLabel", font=("Segoe UI", 10, "bold"), foreground="#00ff88")
        self.style.configure("TCombobox", fieldbackground="#2d2d2d", background="#3d3d3d", foreground="#ffffff", font=("Segoe UI", 10))
        self.style.configure("TButton", font=("Segoe UI", 9), background="#333333", foreground="#ffffff")
        self.style.map("TButton", background=[("active", "#444444")])

        # Header Frame
        header = ttk.Label(root, text="Insta360 Studio - Live LUT Switcher", style="Header.TLabel")
        header.pack(pady=(14, 2))

        subtitle = ttk.Label(root, text="Select any LUT below to apply it instantly to Studio", style="Status.TLabel")
        subtitle.pack(pady=(0, 12))

        # Dropdown Frame
        drop_frame = ttk.Frame(root)
        drop_frame.pack(fill="x", padx=25, pady=5)

        ttk.Label(drop_frame, text="Active LUT:").pack(anchor="w", pady=(0, 4))
        
        self.lut_combo = ttk.Combobox(drop_frame, state="readonly", width=38)
        self.lut_combo.pack(fill="x", pady=2)
        self.lut_combo.bind("<<ComboboxSelected>>", self.on_lut_selected)

        # Active Status Label
        self.active_label = ttk.Label(root, text="Status: Ready", style="Active.TLabel")
        self.active_label.pack(pady=(8, 2))

        hint_label = ttk.Label(root, text="Tip: Flip the 'LUT' switch in Studio OFF & ON to refresh", font=("Segoe UI", 8, "italic"), foreground="#888888")
        hint_label.pack(pady=(0, 10))

        # Bottom Button Frame
        btn_frame = ttk.Frame(root)
        btn_frame.pack(fill="x", padx=25, pady=(5, 10))

        self.btn_open = ttk.Button(btn_frame, text="📁 Open LUTs Folder", command=self.open_luts_folder)
        self.btn_open.pack(side="left", expand=True, fill="x", padx=(0, 5))

        self.btn_refresh = ttk.Button(btn_frame, text="🔄 Refresh List", command=self.refresh_lut_list)
        self.btn_refresh.pack(side="right", expand=True, fill="x", padx=(5, 0))

        # Initial populate
        self.refresh_lut_list()

    def get_available_luts(self):
        files = [f for f in os.listdir(CUSTOM_LUTS_DIR) if f.lower().endswith(".cube")]
        files.sort()
        return files

    def refresh_lut_list(self):
        luts = self.get_available_luts()
        if not luts:
            self.lut_combo["values"] = ["No .cube files found in Custom_LUTs"]
            self.lut_combo.current(0)
            self.active_label.config(text="⚠️ Please drop .cube files into the Custom_LUTs folder", foreground="#ffbb00")
            return

        self.lut_combo["values"] = luts
        
        # Try to detect which one is active
        active_found = False
        target_sample = os.path.join(STUDIO_ILOG_DIR, TARGET_LUTS[0])
        if os.path.exists(target_sample):
            try:
                with open(target_sample, "rb") as f:
                    sample_bytes = f.read(1024)
                for lut in luts:
                    lut_p = os.path.join(CUSTOM_LUTS_DIR, lut)
                    with open(lut_p, "rb") as lf:
                        if lf.read(1024) == sample_bytes:
                            self.lut_combo.set(lut)
                            self.active_label.config(text=f"Active: {lut}", foreground="#00ff88")
                            active_found = True
                            break
            except Exception:
                pass

        if not active_found and luts:
            self.lut_combo.current(0)
            self.active_label.config(text=f"Selected: {luts[0]} (Click to activate)", foreground="#aaaaaa")

    def on_lut_selected(self, event=None):
        selected_lut = self.lut_combo.get()
        if not selected_lut or selected_lut.startswith("No .cube"):
            return

        src_path = os.path.join(CUSTOM_LUTS_DIR, selected_lut)
        if not os.path.exists(src_path):
            messagebox.showerror("Error", f"File not found: {selected_lut}")
            return

        try:
            for target_name in TARGET_LUTS:
                dest = os.path.join(STUDIO_ILOG_DIR, target_name)
                shutil.copyfile(src_path, dest)
            self.active_label.config(text=f"Active: {selected_lut} ✓", foreground="#00ff88")
        except PermissionError:
            # Fallback: run elevated copy command
            try:
                ps_cmd = f"Copy-Item '{src_path}' '{os.path.join(STUDIO_ILOG_DIR, TARGET_LUTS[0])}' -Force"
                subprocess.run(["powershell", "-Command", f"Start-Process powershell -ArgumentList '-NoProfile -Command {ps_cmd}' -Verb RunAs"], check=True)
                self.active_label.config(text=f"Active: {selected_lut} ✓", foreground="#00ff88")
            except Exception as e:
                messagebox.showerror("Permission Error", f"Could not copy LUT: {e}\nPlease run as Administrator once to set permissions.")
        except Exception as e:
            messagebox.showerror("Error", f"Failed to apply LUT: {e}")

    def open_luts_folder(self):
        os.startfile(CUSTOM_LUTS_DIR)

if __name__ == "__main__":
    app_root = tk.Tk()
    app = LutSwitcherApp(app_root)
    app_root.mainloop()
