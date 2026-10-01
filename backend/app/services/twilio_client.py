from twilio.rest import Client
from twilio.base.exceptions import TwilioRestException
from ..core.config import get_settings
import logging

logger = logging.getLogger(__name__)


class TwilioClient:
    """
    Wraps Twilio SMS and Voice APIs.
    All methods are no-ops when Twilio credentials are not configured.
    """

    def __init__(self):
        self.settings = get_settings()
        self._client: Client | None = None
        if self._is_configured:
            try:
                self._client = Client(
                    self.settings.twilio_account_sid,
                    self.settings.twilio_auth_token,
                )
            except Exception as e:
                logger.warning(f"[Twilio] Failed to initialise client: {e}")

    @property
    def _is_configured(self) -> bool:
        s = self.settings
        return bool(s.twilio_account_sid and s.twilio_auth_token and s.twilio_phone_number)

    async def send_sms(self, to: str, body: str) -> bool:
        """Send an SMS to [to]. Returns True on success."""
        if not self._client:
            logger.info(f"[Twilio] SMS skipped (not configured) → {to}")
            return False
        try:
            msg = self._client.messages.create(
                body=body,
                from_=self.settings.twilio_phone_number,
                to=to,
            )
            logger.info(f"[Twilio] SMS sent to {to}: SID={msg.sid}")
            return True
        except TwilioRestException as e:
            logger.error(f"[Twilio] SMS error: {e}")
            return False

    async def make_call(self, to: str, twiml: str | None = None, url: str | None = None) -> bool:
        """Places an automated voice call with inline TwiML speech synthesis or a webhook URL."""
        if not self._client:
            logger.info(f"[Twilio] Voice call skipped (Twilio not configured in .env) → {to}")
            return False
        try:
            kwargs: dict = {
                "from_": self.settings.twilio_phone_number,
                "to": to,
            }
            if twiml:
                kwargs["twiml"] = twiml
            elif url:
                kwargs["url"] = url
            else:
                logger.error("[Twilio] Neither twiml nor url provided for voice call.")
                return False

            call = self._client.calls.create(**kwargs)
            logger.info(f"[Twilio] ✅ Automated AI call initiated to {to}: SID={call.sid}")
            return True
        except TwilioRestException as e:
            logger.error(f"[Twilio] ❌ Voice call error to {to}: {e}")
            return False
        except Exception as e:
            logger.error(f"[Twilio] ❌ Unexpected voice call error to {to}: {e}")
            return False


twilio_client = TwilioClient()
