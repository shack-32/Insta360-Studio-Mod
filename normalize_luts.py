import os
import re

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
                    # CRITICAL: NO trailing space. Qt's QString::split(" ") will create
                    # a 4th empty token if there is a trailing space, breaking
                    # numPixel * 3 == rgb16.size() and crashing with 0xc0000409.
                    data_lines.append(f"{r:.6f} {g:.6f} {b:.6f}\r\n")
                except ValueError:
                    pass

    if not size or len(data_lines) != size**3:
        return None

    out = [f'TITLE "{title}"\r\n', f'LUT_3D_SIZE {size}\r\n\r\n']
    out.extend(data_lines)
    return "".join(out).encode("latin1")

def normalize_file(file_path):
    with open(file_path, "r", encoding="latin1") as f:
        content = f.read()
    fallback = os.path.splitext(os.path.basename(file_path))[0]
    normalized = normalize_cube_content(content, fallback)
    if normalized:
        with open(file_path, "wb") as f:
            f.write(normalized)
        return True
    return False

if __name__ == "__main__":
    lut_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), "Custom_LUTs")
    count = 0
    for fname in os.listdir(lut_dir):
        if fname.lower().endswith(".cube"):
            p = os.path.join(lut_dir, fname)
            if normalize_file(p):
                count += 1
                print(f"[OK] Normalized: {fname}")
            else:
                print(f"[WARN] Could not normalize: {fname}")
    print(f"Total normalized: {count}")
