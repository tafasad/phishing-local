import re
import sys

def main():
    if len(sys.argv) < 2:
        print("Usage: strip_social.py <html_file>", file=sys.stderr)
        sys.exit(1)

    path = sys.argv[1]
    with open(path, "r", encoding="utf-8", errors="ignore") as f:
        html = f.read()

    html = re.sub(r'<script[^>]*src="https?://connect\.facebook\.net[^"]*"[^>]*></script>', '', html, flags=re.IGNORECASE)
    html = re.sub(r'<script[^>]*src="https?://platform\.twitter\.com[^"]*"[^>]*></script>', '', html, flags=re.IGNORECASE)

    with open(path, "w", encoding="utf-8") as f:
        f.write(html)

if __name__ == "__main__":
    main()
