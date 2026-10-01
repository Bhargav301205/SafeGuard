"""
Gmail SMTP Email Service for SafeGuard emergency alerts.

Uses Python's built-in smtplib — completely FREE, no third-party service.
Sends a beautiful HTML email to all emergency contacts when a crash is detected.

Security notes:
- Uses Gmail App Password (NOT your real Gmail password)
- App passwords can only SEND mail — cannot read, delete, or log in to Gmail
- Can be revoked instantly at: myaccount.google.com/apppasswords
- Credentials stored ONLY in backend/.env on your local laptop
- Recommendation: use a dedicated Gmail account (e.g. safeguard.demo@gmail.com)
"""

import smtplib
import logging
import asyncio
from concurrent.futures import ThreadPoolExecutor
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText
from typing import Optional
from ..core.config import settings

logger = logging.getLogger(__name__)

# Thread-pool for blocking SMTP calls (keeps async event loop unblocked)
_smtp_executor = ThreadPoolExecutor(max_workers=2, thread_name_prefix="smtp")

# ── HTML Email Template ────────────────────────────────────────────────────────

_HTML_TEMPLATE = """\
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>SafeGuard Emergency Alert</title>
</head>
<body style="margin:0;padding:0;background:#0d0d0d;font-family:'Segoe UI',Arial,sans-serif;">
  <table width="100%" cellpadding="0" cellspacing="0" style="max-width:580px;margin:0 auto;padding:24px 16px;">
    <tr>
      <td>
        <!-- Header -->
        <div style="background:linear-gradient(135deg,#ff3b30,#ff6b30);border-radius:16px;padding:28px 24px;text-align:center;margin-bottom:20px;">
          <div style="font-size:48px;margin-bottom:8px;">🚨</div>
          <h1 style="color:#fff;margin:0;font-size:24px;font-weight:700;letter-spacing:1px;">EMERGENCY ALERT</h1>
          <p style="color:rgba(255,255,255,0.85);margin:8px 0 0;font-size:14px;">SafeGuard Accident Detection System</p>
        </div>

        <!-- Alert body -->
        <div style="background:#1c1c1e;border-radius:16px;padding:24px;margin-bottom:16px;">
          <p style="color:#fff;font-size:16px;line-height:1.6;margin:0 0 16px;">
            Hi,<br><br>
            <strong style="color:#ff3b30;">{contact_name}</strong>, this is an automated emergency alert.<br><br>
            A possible accident has been detected involving a SafeGuard user.
            Emergency services have been notified.
          </p>

          <!-- Location block -->
          <div style="background:#2c2c2e;border-radius:12px;padding:16px;margin-bottom:16px;">
            <p style="color:rgba(255,255,255,0.5);font-size:11px;margin:0 0 4px;text-transform:uppercase;letter-spacing:1px;">📍 Last Known Location</p>
            <p style="color:#fff;font-size:15px;margin:0 0 12px;font-weight:500;">{address}</p>
            {maps_button}
          </div>

          <!-- Sensor data -->
          <div style="background:#2c2c2e;border-radius:12px;padding:16px;margin-bottom:16px;">
            <p style="color:rgba(255,255,255,0.5);font-size:11px;margin:0 0 12px;text-transform:uppercase;letter-spacing:1px;">📊 Crash Data</p>
            <table width="100%" cellpadding="0" cellspacing="0">
              <tr>
                <td style="color:rgba(255,255,255,0.6);font-size:13px;padding:4px 0;">G-Force Detected</td>
                <td align="right" style="color:#ff9f0a;font-size:13px;font-weight:600;padding:4px 0;">{g_force}G</td>
              </tr>
              <tr>
                <td style="color:rgba(255,255,255,0.6);font-size:13px;padding:4px 0;">Time of Detection</td>
                <td align="right" style="color:#fff;font-size:13px;padding:4px 0;">{timestamp}</td>
              </tr>
            </table>
          </div>

          <!-- Action note -->
          <div style="background:rgba(10,132,255,0.15);border:1px solid rgba(10,132,255,0.3);border-radius:12px;padding:14px;">
            <p style="color:#0a84ff;font-size:13px;margin:0;line-height:1.5;">
              ℹ️ <strong>What to do:</strong> Try calling them immediately. If you cannot reach them, please contact local emergency services (112).
            </p>
          </div>
        </div>

        <!-- Footer -->
        <p style="color:rgba(255,255,255,0.2);font-size:11px;text-align:center;margin:0;">
          This alert was sent automatically by SafeGuard · Do not reply to this email
        </p>
      </td>
    </tr>
  </table>
</body>
</html>
"""

_PLAIN_TEMPLATE = """\
🚨 EMERGENCY ALERT - SafeGuard Accident Detection

Hi {contact_name},

A possible accident has been detected. Emergency services have been notified.

📍 Location: {address}
{maps_url_text}
📊 G-Force: {g_force}G
🕐 Time: {timestamp}

Please try to contact the person immediately.
If unreachable, call emergency services: 112

---
This message was sent automatically by SafeGuard.
Do not reply to this email.
"""


class EmailService:
    """Sends HTML emergency emails via Gmail SMTP (free, no third-party needed)."""

    def _build_email(
        self,
        to_name: str,
        to_email: str,
        address: str,
        lat: float,
        lng: float,
        g_force: float,
        timestamp: str,
    ) -> MIMEMultipart:
        msg = MIMEMultipart("alternative")
        msg["Subject"] = "🚨 EMERGENCY ALERT — SafeGuard Accident Detected"
        msg["From"] = f"SafeGuard Alert <{settings.gmail_sender}>"
        msg["To"] = to_email

        maps_url = f"https://maps.google.com/?q={lat},{lng}"
        has_location = lat != 0 or lng != 0

        maps_button = (
            f'<a href="{maps_url}" style="display:inline-block;background:#0a84ff;'
            f'color:#fff;padding:10px 20px;border-radius:10px;text-decoration:none;'
            f'font-size:13px;font-weight:600;">📍 Open in Google Maps</a>'
            if has_location
            else '<p style="color:rgba(255,255,255,0.4);font-size:12px;margin:0;">Location unavailable</p>'
        )

        maps_url_text = f"🗺️ Google Maps: {maps_url}" if has_location else "🗺️ Location unavailable"

        html = _HTML_TEMPLATE.format(
            contact_name=to_name,
            address=address or "Location unavailable",
            maps_button=maps_button,
            g_force=f"{g_force:.1f}",
            timestamp=timestamp,
        )
        plain = _PLAIN_TEMPLATE.format(
            contact_name=to_name,
            address=address or "Location unavailable",
            maps_url_text=maps_url_text,
            g_force=f"{g_force:.1f}",
            timestamp=timestamp,
        )

        msg.attach(MIMEText(plain, "plain"))
        msg.attach(MIMEText(html, "html"))
        return msg

    async def send_alert(
        self,
        contacts: list[dict],  # [{"name": ..., "email": ...}]
        address: str,
        lat: float,
        lng: float,
        g_force: float = 0.0,
        timestamp: Optional[str] = None,
    ) -> list[str]:
        """
        Sends emergency email to each contact.
        Returns list of email addresses successfully sent.
        Runs blocking SMTP in a thread executor to avoid freezing the event loop.
        """
        sender = (settings.gmail_sender or "").strip()
        password = (settings.gmail_app_password or "").replace(" ", "").strip()

        if not sender or not password:
            logger.warning("[Email] Gmail credentials not configured. Skipping email alerts.")
            return []

        if not contacts:
            return []

        ts = timestamp or "Unknown"
        messages = []
        for contact in contacts:
            name = contact.get("name", "Emergency Contact")
            email = (contact.get("email") or "").strip()
            if not email or "@" not in email:
                continue
            msg = self._build_email(
                to_name=name,
                to_email=email,
                address=address,
                lat=lat,
                lng=lng,
                g_force=g_force,
                timestamp=ts,
            )
            messages.append((name, email, msg))

        if not messages:
            return []

        def _send_all() -> list[str]:
            """Blocking SMTP work — runs in thread executor."""
            sent: list[str] = []
            try:
                with smtplib.SMTP_SSL("smtp.gmail.com", 465, timeout=10) as smtp:
                    smtp.login(sender, password)
                    logger.info(f"[Email] Connected to Gmail SMTP as {sender}")
                    for name, email, msg in messages:
                        try:
                            smtp.sendmail(sender, email, msg.as_string())
                            sent.append(email)
                            logger.info(f"[Email] ✅ Sent to {name} <{email}>")
                        except Exception as e:
                            logger.error(f"[Email] ❌ Failed to send to {email}: {e}")
            except smtplib.SMTPAuthenticationError:
                logger.error(
                    "[Email] Gmail authentication failed. "
                    "Check GMAIL_SENDER and GMAIL_APP_PASSWORD in .env"
                )
            except Exception as e:
                logger.error(f"[Email] SMTP connection error: {e}")
            return sent

        loop = asyncio.get_event_loop()
        notified: list[str] = await loop.run_in_executor(_smtp_executor, _send_all)
        return notified


email_service = EmailService()
