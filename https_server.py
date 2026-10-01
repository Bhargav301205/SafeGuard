"""
HTTPS server for the SafeGuard Flutter web app.
Serves build/web over HTTPS so Chrome on Android allows the Geolocation API.

Usage:
  python https_server.py

Opens port 3443 with SSL. Access via:
  https://<LAN_IP>:3443
  (Accept the security warning on first visit — click Advanced → Proceed)
"""

import http.server
import ssl
import os
import socket

# ── Config ─────────────────────────────────────────────────────────────────────
PORT = 3000  # Uses existing firewall rule — no admin needed
WEB_DIR = os.path.join(os.path.dirname(__file__), "mobile-app", "build", "web")
CERT = os.path.join(os.path.dirname(__file__), "cert.pem")
KEY  = os.path.join(os.path.dirname(__file__), "key.pem")

# ── Detect LAN IP ──────────────────────────────────────────────────────────────
def get_lan_ip():
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        s.connect(("8.8.8.8", 80))
        return s.getsockname()[0]
    finally:
        s.close()

# ── Check certs exist ───────────────────────────────────────────────────────────
if not os.path.exists(CERT) or not os.path.exists(KEY):
    print("[ERROR] cert.pem / key.pem not found. Run: python gen_cert.py first")
    exit(1)

if not os.path.isdir(WEB_DIR):
    print(f"[ERROR] Web directory not found: {WEB_DIR}")
    print("        Run: flutter build web --release  first")
    exit(1)

# ── Start HTTPS server ─────────────────────────────────────────────────────────
os.chdir(WEB_DIR)

handler = http.server.SimpleHTTPRequestHandler

context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
context.load_cert_chain(CERT, KEY)

with http.server.HTTPServer(("0.0.0.0", PORT), handler) as httpd:
    httpd.socket = context.wrap_socket(httpd.socket, server_side=True)
    lan_ip = get_lan_ip()
    print("=" * 55)
    print(f"  SafeGuard HTTPS Server running on port {PORT}")
    print("=" * 55)
    print(f"  Laptop:  https://localhost:{PORT}")
    print(f"  Phone:   https://{lan_ip}:{PORT}")
    print()
    print("  On phone: Accept the security warning once")
    print("  (tap Advanced → Proceed to site)")
    print("  After that, GPS/Location will work fully!")
    print("=" * 55)
    httpd.serve_forever()
