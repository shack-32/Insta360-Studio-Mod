import os
import json
import shutil
from http.server import HTTPServer, BaseHTTPRequestHandler
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
    files.sort()
    return files

def get_active_index(files):
    sample = os.path.join(STUDIO_ILOG_DIR, TARGET_LUTS[0])
    if not os.path.exists(sample):
        return 0
    try:
        with open(sample, "rb") as f:
            sample_bytes = f.read(1024)
        for idx, f_name in enumerate(files):
            p = os.path.join(CUSTOM_LUTS_DIR, f_name)
            with open(p, "rb") as f:
                if f.read(1024) == sample_bytes:
                    return idx
    except Exception:
        pass
    return 0

def format_lut_label(filename):
    # Clean up filename for display in dropdown
    name = os.path.splitext(filename)[0]
    name = name.replace("_", " ").replace("-", " ")
    if len(name) > 28:
        name = name[:26] + "..."
    return name

class LutRequestHandler(BaseHTTPRequestHandler):
    def log_message(self, format, *args):
        pass # Silent logging

    def end_headers(self):
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, OPTIONS")
        super().end_headers()

    def do_OPTIONS(self):
        self.send_response(200)
        self.end_headers()

    def do_GET(self):
        parsed = urlparse(self.path)
        path = parsed.path
        query = parse_qs(parsed.query)

        files = get_lut_files()

        if path == "/list":
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
                for target_name in TARGET_LUTS:
                    dest = os.path.join(STUDIO_ILOG_DIR, target_name)
                    try:
                        shutil.copyfile(src, dest)
                    except Exception as e:
                        print(f"Error copying {selected}: {e}")
                resp = json.dumps({"status": "ok", "active": selected}).encode("utf-8")
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
    server = HTTPServer(("127.0.0.1", PORT), LutRequestHandler)
    print(f"LUT Background Service listening on http://127.0.0.1:{PORT}")
    server.serve_forever()

if __name__ == "__main__":
    run_server()
