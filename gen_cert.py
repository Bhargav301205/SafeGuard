"""
Generates a self-signed SSL certificate (cert.pem + key.pem) for
serving the SafeGuard Flutter web app over HTTPS on the LAN.

Chrome on Android REQUIRES HTTPS for the Geolocation API.
This script creates a certificate valid for 365 days for the current LAN IP.
"""

import ipaddress
import socket
import datetime
from cryptography import x509
from cryptography.x509.oid import NameOID
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import rsa

# ── Detect current LAN IP ──────────────────────────────────────────────────────
def get_lan_ip():
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        s.connect(("8.8.8.8", 80))
        return s.getsockname()[0]
    finally:
        s.close()

lan_ip = get_lan_ip()
print(f"[SSL] Detected LAN IP: {lan_ip}")

# ── Generate RSA private key ───────────────────────────────────────────────────
key = rsa.generate_private_key(public_exponent=65537, key_size=2048)

# ── Build certificate ──────────────────────────────────────────────────────────
subject = issuer = x509.Name([
    x509.NameAttribute(NameOID.COUNTRY_NAME, "IN"),
    x509.NameAttribute(NameOID.STATE_OR_PROVINCE_NAME, "Local"),
    x509.NameAttribute(NameOID.LOCALITY_NAME, "SafeGuard"),
    x509.NameAttribute(NameOID.ORGANIZATION_NAME, "SafeGuard Exhibition"),
    x509.NameAttribute(NameOID.COMMON_NAME, lan_ip),
])

cert = (
    x509.CertificateBuilder()
    .subject_name(subject)
    .issuer_name(issuer)
    .public_key(key.public_key())
    .serial_number(x509.random_serial_number())
    .not_valid_before(datetime.datetime.utcnow())
    .not_valid_after(datetime.datetime.utcnow() + datetime.timedelta(days=365))
    .add_extension(
        x509.SubjectAlternativeName([
            x509.DNSName("localhost"),
            x509.IPAddress(ipaddress.IPv4Address(lan_ip)),
            x509.IPAddress(ipaddress.IPv4Address("127.0.0.1")),
        ]),
        critical=False,
    )
    .sign(key, hashes.SHA256())
)

# ── Write cert.pem and key.pem ─────────────────────────────────────────────────
with open("cert.pem", "wb") as f:
    f.write(cert.public_bytes(serialization.Encoding.PEM))

with open("key.pem", "wb") as f:
    f.write(key.private_bytes(
        serialization.Encoding.PEM,
        serialization.PrivateFormat.TraditionalOpenSSL,
        serialization.NoEncryption(),
    ))

print(f"[SSL] cert.pem and key.pem generated successfully")
print(f"[SSL] Valid for: localhost, {lan_ip}, 127.0.0.1")
print(f"[SSL] Expires: {datetime.datetime.utcnow() + datetime.timedelta(days=365)}")
