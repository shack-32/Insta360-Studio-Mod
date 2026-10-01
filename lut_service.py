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
PORT = 8999

TARGET_LUTS = [
    "X5_I-Log_To_Rec.709_V1.0.cube",
    "AcePro2_I-Log_To_Rec.709_V1.0.cube",
    "X6_I-Log_To_Rec.709_V1.4.cube",
    "Luna_I-Log_to_Rec709.cube"
]

def get_lut_files():
    if not os.path.exists(CUSTOM_LUTS_DIR):
        return []
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
}

def format_lut_label(filename):
    if filename in KNOWN_LABELS:
        return KNOWN_LABELS[filename]
    name = os.path.splitext(filename)[0]
    if name.startswith("00_"):
        name = name[3:]
    name = re.sub(r'[\._\-]+', ' ', name)
    name = re.sub(r'\s+', ' ', name).strip()
    words = [w.capitalize() if not w.isupper() else w for w in name.split(' ')]
    name = " ".join(words)
    if len(name) > 26:
        name = name[:24] + ".."
    return name

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
        # Keep silent to avoid console clutter
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

        files = get_lut_files()

        if path == "/ping":
            resp = b'{"status":"ok"}'
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(resp)))
            self.end_headers()
            self.wfile.write(resp)

        elif path == "/list":
            labels = [format_lut_label(f) for f in files]
            active_idx = get_active_index(files)
            resp = json.dumps({
                "files": files,
                "labels": labels,
                "active_index": active_idx
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
                success_count = 0
                for target_name in TARGET_LUTS:
                    dest = os.path.join(STUDIO_ILOG_DIR, target_name)
                    try:
                        shutil.copyfile(src, dest)
                        success_count += 1
                    except Exception as e:
                        pass
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

        else:
            self.send_response(404)
            self.end_headers()

def run_server():
    server = ThreadingHTTPServer(("127.0.0.1", PORT), LutRequestHandler)
    server.daemon_threads = True
    server.serve_forever()

if __name__ == "__main__":
    run_server()
