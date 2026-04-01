import os
import re

ROOT = os.path.abspath(os.getcwd())

def fix_mojibake_line(line: str) -> str:
    if ("Ã" in line) or ("Ä" in line) or ("Å" in line):
        try:
            return line.encode("latin1").decode("utf-8")
        except Exception:
            return line
    return line

def fix_file_lines(path: str) -> None:
    if not os.path.exists(path):
        return
    with open(path, "rb") as f:
        raw = f.read()
    try:
        text = raw.decode("utf-8")
    except Exception:
        text = raw.decode("utf-8", errors="ignore")
    lines = re.split(r"(\r\n|\n|\r)", text)
    out = []
    for i in range(0, len(lines), 2):
        line = lines[i]
        sep = lines[i+1] if i+1 < len(lines) else ""
        out.append(fix_mojibake_line(line) + sep)
    fixed = "".join(out)
    with open(path, "wb") as f:
        f.write(fixed.encode("utf-8"))

def ensure_utf8_meta(path: str) -> None:
    if not os.path.exists(path):
        return
    with open(path, "rb") as f:
        raw = f.read()
    try:
        html = raw.decode("utf-8")
    except Exception:
        html = raw.decode("utf-8", errors="ignore")
    if '<meta charset="utf-8">' not in html.lower():
        m = re.search(r"<head[^>]*>", html, flags=re.IGNORECASE)
        if m:
            ins = m.end()
            html = html[:ins] + '\n    <meta charset="utf-8">' + html[ins:]
    with open(path, "wb") as f:
        f.write(html.encode("utf-8"))

def main():
    fix_file_lines(os.path.join(ROOT, "lib", "main.dart"))
    ensure_utf8_meta(os.path.join(ROOT, "web", "index.html"))

if __name__ == "__main__":
    main()
