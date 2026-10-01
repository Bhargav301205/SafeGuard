import logging
from ..services.twilio_client import twilio_client

logger = logging.getLogger(__name__)

_SMS_TEMPLATE = (
    "🚨 EMERGENCY ALERT: {name} may have been in an accident.\n"
    "Location: {address}\n"
    "Live map: {maps_url}\n"
    "This message was sent automatically by SafeGuard."
)


_AI_VOICE_TWIML = """\
<Response>
    <Pause length="1"/>
    <Say voice="Polly.Aditi" language="en-IN">
        Emergency Alert. A vehicle accident has been detected involving your emergency contact, {name}.
        The location of the incident is near {address}.
        An email containing the exact live Google Maps location has been sent to your email inbox.
        Please check your email immediately or contact emergency services on 1 1 2.
    </Say>
    <Pause length="2"/>
    <Say voice="Polly.Aditi" language="en-IN">
        Repeating emergency alert. Accident detected near {address}. Please check your email for the live location map.
    </Say>
</Response>
"""


class NotificationService:
    """Orchestrates sending emergency SMS and automated AI voice calls."""

    async def call_contacts(
        self,
        contacts: list[dict],  # [{"name": ..., "phone": ...}]
        address: str,
        lat: float,
        lng: float,
    ) -> list[str]:
        """
        Places automated AI voice calls to each contact phone number using Twilio TTS.
        When answered, speaks the crash alert, location, and points them to the email map.
        Returns a list of phone numbers successfully called.
        """
        clean_address = (address or "Location unavailable").replace("&", " and ").replace("<", "").replace(">", "")
        called: list[str] = []

        for contact in contacts:
            phone = (contact.get("phone") or "").strip()
            name = (contact.get("name") or "Emergency Contact").replace("&", " and ").replace("<", "").replace(">", "")
            if not phone:
                continue

            twiml = _AI_VOICE_TWIML.format(
                name=name,
                address=clean_address,
            )

            ok = await twilio_client.make_call(to=phone, twiml=twiml)
            if ok:
                called.append(phone)
                logger.info(f"[NotificationService] ✅ AI voice call placed to {name} ({phone})")
            else:
                logger.info(f"[NotificationService] Voice call to {phone} skipped or failed.")

        return called

    async def notify_contacts(
        self,
        phone_numbers: list[str],
        victim_name: str,
        address: str,
        lat: float,
        lng: float,
    ) -> list[str]:
        """
        Sends emergency SMS to each number via Twilio.
        Returns a list of phone numbers that were successfully notified.
        """
        maps_url = f"https://maps.google.com/?q={lat},{lng}"
        body = _SMS_TEMPLATE.format(
            name=victim_name,
            address=address,
            maps_url=maps_url,
        )

        notified: list[str] = []
        for number in phone_numbers:
            ok = await twilio_client.send_sms(to=number, body=body)
            if ok:
                notified.append(number)
            else:
                logger.info(
                    f"[NotificationService] SMS to {number} not sent via Twilio "
                    "(will be handled by device native SMS intent)"
                )
        return notified


notification_service = NotificationService()
