# SafeGuard — Accident Detection & Auto-Emergency-Response

A mission-critical cross-platform emergency response system that detects vehicle and personal accidents in real time using onboard mobile sensors, ML-powered false-positive filters, and an **Automated Emergency Calling & Alerting System** powered by Twilio, native device telephony, and real-time GPS telemetry.

---

## Key Features

- 🚨 **Real-Time Crash Detection**: Samples accelerometer, gyroscope, and GPS velocity at 20Hz. Evaluates multi-sensor thresholds and ML classifier to detect impacts instantly.
- 📞 **Automated Emergency Calling System (Twilio Voice)**:
  - Automated AI voice calls placed immediately to registered emergency contacts upon accident confirmation.
  - Text-to-Speech (TwiML / Amazon Polly) vocalizes victim details, real-time accident location, and nearest landmarks.
  - Works seamlessly via Twilio Cloud Voice API with retry reliability.
- 📱 **Device Native Emergency Auto-Dialer**:
  - Automatically triggers direct phone calls to emergency services (112 / 911).
  - Android: Automated one-touch direct dial intent (`CALL_PHONE`).
  - iOS: Pre-filled dialer with one-tap emergency confirmation (Apple safety policy compliant).
- 📍 **Live GPS Location & Geocoding**: Reverse-geocodes exact accident coordinates and attaches live Google Maps links.
- 💬 **Emergency SMS & Email Broadcast**:
  - Automated Twilio SMS alerts dispatched with live tracking links.
  - High-priority HTML emergency emails detailing G-force impact telemetry, exact timestamp, and map links.
- 🏥 **Nearest Emergency Services**: Discovers and routes to the closest hospitals and police stations via Google Places API.

---

## Project Structure

```
rasana/
├── mobile-app/          # Flutter application (Android, iOS & Web)
│   ├── lib/
│   │   ├── core/        # App constants, background services, permissions
│   │   ├── sensors/     # Accelerometer, gyroscope, GPS, crash detector, ML classifier
│   │   ├── emergency/   # Countdown UI, Auto-call service, SMS service, nearest services
│   │   ├── contacts/    # Emergency contacts repository (SQLite + Backend sync)
│   │   ├── maps/        # Google Maps integration & live tracking
│   │   ├── models/      # Sensor readings, crash incidents, emergency contacts
│   │   └── ui/          # Modern dashboard, incident log, settings, medical profile
│   ├── android/         # Android manifest, permissions (CALL_PHONE, ACCESS_FINE_LOCATION)
│   └── ios/             # iOS Info.plist & background modes
│
├── backend/             # High-performance FastAPI backend
│   └── app/
│       ├── api/         # Incidents, contacts, emergency services, user profile endpoints
│       ├── core/        # Configuration, environment settings, API security
│       ├── db/          # Database engine (SQLite / PostgreSQL) & CRUD operations
│       ├── models/      # SQLAlchemy ORM models & Pydantic schemas
│       └── services/    # Twilio Voice/SMS client, Google Maps client, Email service
│
├── ml/                  # Machine Learning false-positive reduction module
│   ├── data/            # Impact sensor datasets (accelerometer/gyroscope sequences)
│   ├── train_classifier.py # ML model training script
│   └── model_weights.json  # Exported classifier weights used by mobile app
│
└── docs/                # Architecture diagrams & API documentation
    ├── architecture.md  # Detailed system architecture
    └── api-spec.md      # OpenAPI specification
```

---

## Emergency Calling & Response Flow

```
                     [ Onboard Sensor Monitoring (20Hz) ]
                                      │
                     [ Multi-Signal Crash Verification ]
                        (Accel ≥ 3.5G + Gyro + GPS Drop)
                                      │
                                      ▼
                      [ 30-Second Countdown Screen ]
                      ("I'M OK — CANCEL" Override)
                                      │ (No cancel)
                                      ▼
                 [ GPS Coordinates & Geocoding Locked ]
                                      │
         ┌────────────────────────────┼────────────────────────────┐
         │                            │                            │
         ▼                            ▼                            ▼
  📞 TWILIO VOICE CALL       📱 DEVICE AUTO-DIALER        💬 SMS & EMAIL ALERTS
Automated voice calls placed  Native phone dialer         Twilio SMS & high-priority
to emergency contacts via     dials 112 / 911             alert emails sent with live
Twilio AI TTS with location  (Direct / One-tap)          Google Maps navigation link
         │                            │                            │
         └────────────────────────────┼────────────────────────────┘
                                      │
                                      ▼
                 [ Incident Logged to SQLite & Synced to Cloud ]
```

---

## Emergency Calling System Details

### 1. Twilio Automated Voice Calling Pipeline
When an incident is confirmed, the backend's `NotificationService` calls `TwilioClient.make_call()`.
- Generates dynamic **TwiML** containing clean address and victim identity:
  ```xml
  <Response>
      <Pause length="1"/>
      <Say voice="Polly.Aditi" language="en-IN">
          Emergency Alert. A vehicle accident has been detected involving your emergency contact, {name}.
          The location of the incident is near {address}.
          Please check your email and messages immediately or contact emergency services on 112.
      </Say>
  </Response>
  ```
- Handles call states, retry logic, and fallback gracefully if credentials are not configured.

### 2. On-Device Native Emergency Calling
The mobile app includes `AutoCallService`:
- Instantly launches the telephony system with the configured emergency dispatch number (defaults to `112`).
- Integrated with safety countdown: if the user does not tap "I'M OK", the call is initiated alongside location dispatch.

---

## Quick Start

### 1. Backend Setup

```bash
cd backend

# Create and configure environment variables
cp .env.example .env

# Install dependencies
pip install -r requirements.txt

# Run the FastAPI server
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```
Interactive API docs available at: **http://localhost:8000/docs**

### 2. Twilio Configuration (Emergency Calling & SMS)

In `backend/.env`, configure your Twilio account credentials:

```ini
# Twilio Voice & SMS Configuration
TWILIO_ACCOUNT_SID=your_twilio_account_sid
TWILIO_AUTH_TOKEN=your_twilio_auth_token
TWILIO_PHONE_NUMBER=+1234567890
```

> **Note**: If Twilio credentials are omitted, SafeGuard gracefully falls back to native device calling, SMS intents, and SMTP email alerts without interrupting system execution.

### 3. Flutter Mobile App Setup

#### Requirements
- Flutter SDK (≥ 3.0.0)
- Android Studio / Xcode

#### Google Maps Key Configuration (Android)
Create or edit `mobile-app/android/local.properties`:
```properties
sdk.dir=C:\\Users\\<YOU>\\AppData\\Local\\Android\\Sdk
GOOGLE_MAPS_API_KEY=your_google_maps_api_key_here
```

#### Run the App
```bash
cd mobile-app
flutter pub get
flutter run
```

---

## API Endpoints

| Method | Endpoint | Description |
|---|---|---|
| `GET` | `/health` | Server health check |
| `POST` | `/incidents` | Log crash incident, initiate **Twilio voice calls**, emails & SMS |
| `GET` | `/incidents` | List all past incidents |
| `GET` | `/incidents/{id}` | Get incident details |
| `POST` | `/contacts` | Add/update emergency contacts (phone + email) |
| `GET` | `/contacts` | List all emergency contacts |
| `DELETE` | `/contacts/{id}` | Remove an emergency contact |
| `GET` | `/services/nearest` | Find nearest hospitals and police stations |
| `GET` | `/user/profile` | Retrieve user medical and emergency profile |
| `POST` | `/user/profile` | Update medical info (blood type, allergies, conditions) |

---

## Crash Detection Algorithm

Samples onboard sensors at 20Hz. A crash is flagged when **≥ 2 of 3** conditions fire within a 1-second rolling window:

| Signal | Threshold | Fallback |
|---|---|---|
| **Accelerometer** | ≥ 3.5G resultant magnitude | Always available |
| **Gyroscope** | ≥ 250°/sec angular velocity | Skipped if no gyro (2-of-2 logic) |
| **GPS speed delta** | ≥ 40 km/h drop in ≤ 2 seconds | Available in vehicle / driving mode |

Thresholds can be customized directly in the app's Settings screen.

---

## License

This project is licensed under the MIT License.
