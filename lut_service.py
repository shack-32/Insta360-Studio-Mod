import os
import sys
import json
import shutil
import re
from http.server import ThreadingHTTPServer, BaseHTTPRequestHandler
from urllib.parse import urlparse, parse_qs

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
CUSTOM_LUTS_DIR = os.path.join(SCRIPT_DIR, "Custom_LUTs")
STUDIO_ILOG_DIR = r"C:\Program Files\Insta360 Studio\data\i_log"
LOG_FILE = os.path.join(SCRIPT_DIR, "lut_service.log")
PORT = 8999

TARGET_LUTS = [
    "X5_I-Log_To_Rec.709_V1.0.cube",
    "AcePro2_I-Log_To_Rec.709_V1.0.cube",
    "X6_I-Log_To_Rec.709_V1.4.cube",
    "Luna_I-Log_to_Rec709.cube"
]

def log(msg):
    try:
        with open(LOG_FILE, "a", encoding="utf-8") as f:
            f.write(msg + "\n")
    except Exception:
        pass

def normalize_cube_content(content_str, fallback_title="Custom Look"):
    raw_lines = content_str.splitlines()
    title = fallback_title
    size = None
    data_lines = []

    for line in raw_lines:
        s = line.strip()
        if not s or s.startswith('#'):
            continue
        if s.startswith('TITLE'):
            t = s[5:].strip().strip('"\'')
            if t:
                title = t
        elif s.startswith('LUT_3D_SIZE'):
            parts = s.split()
            if len(parts) >= 2 and parts[1].isdigit():
                size = int(parts[1])
        elif s.startswith('DOMAIN_') or s.startswith('LUT_1D_'):
            continue
        else:
            parts = s.split()
            if len(parts) >= 3:
                try:
                    r = max(0.0, min(1.0, float(parts[0])))
                    g = max(0.0, min(1.0, float(parts[1])))
                    b = max(0.0, min(1.0, float(parts[2])))
                    # CRITICAL: NO trailing space. Qt's QString::split(" ") creates an empty 4th token
                    # if a trailing space is present, causing numPixel * 3 == rgb16.size() to fail and crash!
                    data_lines.append(f"{r:.6f} {g:.6f} {b:.6f}\r\n")
                except ValueError:
                    pass

    if not size or len(data_lines) != size**3:
        return None

    out = [f'TITLE "{title}"\r\n', f'LUT_3D_SIZE {size}\r\n\r\n']
    out.extend(data_lines)
    return "".join(out).encode("latin1")

def deploy_lut_to_studio(src_path):
    try:
        with open(src_path, "r", encoding="latin1") as f:
            content = f.read()
        fallback = os.path.splitext(os.path.basename(src_path))[0]
        normalized = normalize_cube_content(content, fallback)
        if not normalized:
            # Safe fallback if input file corrupted
            stock_path = os.path.join(CUSTOM_LUTS_DIR, "00_Stock_Rec709.cube")
            with open(stock_path, "rb") as f:
                normalized = f.read()

        success = 0
        for target in TARGET_LUTS:
            dest = os.path.join(STUDIO_ILOG_DIR, target)
            try:
                with open(dest, "wb") as f:
                    f.write(normalized)
                success += 1
            except Exception:
                pass
        return success
    except Exception as e:
        log(f"Error deploying LUT: {e}")
        return 0

def get_lut_files():
    if not os.path.exists(CUSTOM_LUTS_DIR):
        return []
    # Dynamic live rescan of the Custom_LUTs directory
    files = [f for f in os.listdir(CUSTOM_LUTS_DIR) if f.lower().endswith(".cube")]
    # Ensure stock is first
    stock_files = [f for f in files if "stock" in f.lower() or f.startswith("00_")]
    other_files = [f for f in files if f not in stock_files]
    stock_files.sort()
    other_files.sort(key=lambda s: s.lower())
    return stock_files + other_files

KNOWN_LABELS = {
    "00_Stock_Rec709.cube": "Stock Rec.709",
    "7Drk21.cube": "7Drk Dark Night",
    "Art_Luts.cube": "Art LUTs",
    "awalk_lut_7.A001_06170540_C038.cube": "A Walk In Park",
    "BLUE_HORROR_REC709_V1.cube": "Blue Horror Film",
    "Blue_Phantom.cube": "Blue Phantom",
    "cannon_cool_corr_look_224.9R8A3608.cube": "Canon Cool Look",
    "Choi_Hung_Estate_02.cube": "Choi Hung Estate",
    "CineStill-800-T-V1.0--N125.cube": "CineStill 800T",
    "Cool_Natural_Breeze.cube": "Cool Natural Breeze",
    "DAY_FOR_NIGHT.cube": "Day For Night",
    "Erdemfilms_NIGHTVISION_gx80__4.P1010446.cube": "Night Vision IR",
    "interview-cool_17.C0003.cube": "Interview Cool",
    "Johnny_Isaya_1.A030_12160145_C051.cube": "Johnny Isaya Tone",
    "Kodak_2383_Base_Lut_Rec.709_2.4_IG__ashikulislam3251.cube": "Kodak 2383 Film",
    "kuch_hatke_sahil.cube": "Warm Amber Glow",
    "luck.cube": "Lucky Punch",
    "LUT-G2.cube": "Cinema G2 Look",
    "MERRY_MEN_II.cube": "Merry Men Rich",
    "Ramazan-Kocaturk-Slog3_to_cinematic-dis-cekim-121.cube": "Cinematic Golden Hour",
    "SMDfilm_net.cube": "SMD Film Color",
    "TDH-LUT.cube": "TDH Rich Contrast",
    "TP-REC709_Gam_Corr.cube": "Gamma Correct Film",
    "Untitled_1.MVI_0401.cube": "Vivid Daylight",
    "X5_I-Log_To_Rec.709_V1.0.cube": "X5 Official I-Log",
    "Fuji ETERNA 250D Fuji 3510 (by Adobe).cube": "Fuji Eterna 250D 3510",
    "Fuji ETERNA 250D Kodak 2395 (by Adobe).cube": "Fuji Eterna 250D 2395",
    "Fuji F125 Kodak 2393 (by Adobe).cube": "Fuji F125 Kodak 2393",
    "Fuji F125 Kodak 2395 (by Adobe).cube": "Fuji F125 Kodak 2395",
    "Fuji REALA 500D Kodak 2393 (by Adobe).cube": "Fuji Reala 500D 2393",
    "Kodak 5205 Fuji 3510 (by Adobe).cube": "Kodak 5205 Fuji 3510",
    "Kodak 5218 Kodak 2383 (by Adobe).cube": "Kodak 5218 Kodak 2383",
    "Kodak 5218 Kodak 2395 (by Adobe).cube": "Kodak 5218 Kodak 2395",
    "Exterior.cube": "Exterior Daylight",
    "Interior.cube": "Interior Ambient",
    "HDR.cube": "HDR Punch",
    "Hyperlapse.cube": "Hyperlapse Vivid",
    "Night.cube": "Night City Lights",
    "rec709_natural_look_82.2G4A0029.cube": "Natural Rec709 Look",
    "---_M.Fahri_-_AnalogFilmPack_-_100c_Negative.cube": "Analog 100c Negative",
    "---_M.Fahri_-_AnalogFilmPack_-_400h.cube": "Analog Film 400h",
    "---_M.Fahri_-_AnalogFilmPack_-_Portrait_400_Nc.cube": "Portrait 400 NC"
}

def format_lut_label(filename):
    if filename in KNOWN_LABELS:
        return KNOWN_LABELS[filename]
    name = os.path.splitext(filename)[0]
    if name.startswith("00_") or name.startswith("---_"):
        name = name.lstrip("-0_")
    name = re.sub(r'\(by Adobe\)', '', name, flags=re.IGNORECASE)
    name = re.sub(r'[\._\-]+', ' ', name)
    name = re.sub(r'\s+', ' ', name).strip()
    words = [w.capitalize() if not w.isupper() else w for w in name.split(' ')]
    name = " ".join(words)
    if len(name) > 24:
        name = name[:22] + ".."
    return name

def reset_to_stock():
    stock_path = os.path.join(CUSTOM_LUTS_DIR, "00_Stock_Rec709.cube")
    if not os.path.exists(stock_path):
        return False
    return deploy_lut_to_studio(stock_path) == len(TARGET_LUTS)

def get_active_index(files):
    sample = os.path.join(STUDIO_ILOG_DIR, TARGET_LUTS[0])
    if not os.path.exists(sample) or not files:
        return 0
    try:
        sample_size = os.path.getsize(sample)
        with open(sample, "rb") as f:
            sample_bytes = f.read(2048)
        for idx, f_name in enumerate(files):
            p = os.path.join(CUSTOM_LUTS_DIR, f_name)
            if os.path.getsize(p) == sample_size:
                with open(p, "rb") as f2:
                    if f2.read(2048) == sample_bytes:
                        return idx
    except Exception:
        pass
    return 0

class LutRequestHandler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def log_message(self, format, *args):
        pass

    def end_headers(self):
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, OPTIONS")
        self.send_header("Connection", "close")
        super().end_headers()

    def do_OPTIONS(self):
        self.send_response(200)
        self.end_headers()

    def do_GET(self):
        parsed = urlparse(self.path)
        path = parsed.path
        query = parse_qs(parsed.query)

        # Dynamic rescan on every request
        files = get_lut_files()

        if path == "/ping":
            resp = json.dumps({"status": "ok", "lut_count": len(files)}).encode("utf-8")
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(resp)))
            self.end_headers()
            self.wfile.write(resp)

        elif path in ("/list", "/rescan"):
            labels = [format_lut_label(f) for f in files]
            active_idx = get_active_index(files)
            resp = json.dumps({
                "files": files,
                "labels": labels,
                "active_index": active_idx,
                "count": len(files)
            }).encode("utf-8")
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(resp)))
            self.end_headers()
            self.wfile.write(resp)

        elif path == "/reset":
            ok = reset_to_stock()
            resp = json.dumps({
                "status": "ok" if ok else "error",
                "active": "00_Stock_Rec709.cube",
                "index": 0,
                "count": len(files)
            }).encode("utf-8")
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(resp)))
            self.end_headers()
            self.wfile.write(resp)

        elif path == "/switch":
            idx = int(query.get("index", [0])[0])
            if 0 <= idx < len(files):
                selected = files[idx]
                src = os.path.join(CUSTOM_LUTS_DIR, selected)
                # Automatically normalizes formatting to prevent any engine crashes
                success_count = deploy_lut_to_studio(src)
                resp = json.dumps({
                    "status": "ok",
                    "active": selected,
                    "index": idx,
                    "copied": success_count
                }).encode("utf-8")
            else:
                resp = json.dumps({"status": "error", "message": "invalid index"}).encode("utf-8")
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(resp)))
            self.end_headers()
            self.wfile.write(resp)

        elif path == "/denoise":
            flag_file = r"C:\Users\Public\denoise.flag"
            if "enabled" in query:
                val = query["enabled"][0].strip().lower()
                if val in ("1", "true", "yes", "on"):
                    try:
                        with open(flag_file, "wb") as f:
                            f.write(b"1")
                        log("Export Noise Reduction ENABLED (C:\\Users\\Public\\denoise.flag created)")
                    except Exception as e:
                        log(f"Error creating denoise flag: {e}")
                else:
                    if os.path.exists(flag_file):
                        try:
                            os.remove(flag_file)
                            log("Export Noise Reduction DISABLED (C:\\Users\\Public\\denoise.flag removed)")
                        except Exception as e:
                            log(f"Error removing denoise flag: {e}")
            is_enabled = os.path.exists(flag_file)
            resp = json.dumps({"status": "ok", "enabled": is_enabled}).encode("utf-8")
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(resp)))
            self.end_headers()
            self.wfile.write(resp)

        else:
            self.send_response(404)
            self.end_headers()

def run_server():
    reset_to_stock()
    flag_file = r"C:\Users\Public\denoise.flag"
    if os.path.exists(flag_file):
        try:
            os.remove(flag_file)
        except Exception:
            pass
    files = get_lut_files()
    log(f"Server started on port {PORT}. Rescanned Custom_LUTs: found {len(files)} .cube files.")
    server = ThreadingHTTPServer(("127.0.0.1", PORT), LutRequestHandler)
    server.daemon_threads = True
    server.serve_forever()

if __name__ == "__main__":
    run_server()
