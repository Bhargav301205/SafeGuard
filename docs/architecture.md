# SafeGuard — Technical Architecture Document

## 1. System Overview

**SafeGuard** (Rasana) is an automatic crash detection and emergency response system. It continuously samples smartphone telemetry (accelerometer, gyroscope, GPS) to detect vehicle and personal collisions. When a crash is detected, the system initiates a 30-second cancellation window for the victim. If uncancelled, it dispatches emergency calls to first responders (police/ambulance) and alerts registered emergency contacts with real-time GPS location via SMS and backend synchronization.

```
+-------------------------------------------------------------------------+
|                              Phone Sensors                              |
|           Accelerometer (20Hz) | Gyroscope | GPS Position & Speed       |
+-------------------------------------------------------------------------+
                                    |
                                    v
+-------------------------------------------------------------------------+
|                          Sensor Fusion Engine                           |
|        Rule-Based 2-of-3 Evaluator + Rolling Temporal Windows           |
|            (Optional On-Device ML False-Positive Filter)                |
+-------------------------------------------------------------------------+
                                    | [Crash Signature Matched]
                                    v
+-------------------------------------------------------------------------+
|                     30-Second Countdown Window UI                       |
|           Haptic Alerts + Audio Tone + Large 1-Tap Cancel               |
+-------------------------------------------------------------------------+
                    |                                    |
            [User Taps Cancel]                  [Countdown Expires]
                    |                                    |
                    v                                    v
       +-----------------------+           +------------------------------+
       | Log Incident Status:  |           |     Emergency Dispatch       |
       | 'cancelled'           |           +------------------------------+
       +-----------------------+              |              |         |
                                              v              v         v
                                          Auto-Call      Alert SMS  Location
                                          (108/911)      (Contacts)   Map
                                              |              |         |
                                              +--------------+---------+
                                                             |
                                                             v
                                               +---------------------------+
                                               |  FastAPI Cloud Backend    |
                                               |  - Incident Archival      |
                                               |  - Twilio SMS Fallback    |
                                               |  - Nearest Services Proxy |
                                               |  - User Medical Profile   |
                                               +---------------------------+
```

---

## 2. Sensor Processing & Crash Detection Pipeline

### 2.1 Telemetry Streams & Sampling Rates
- **Accelerometer**: Sampled at 20–50 Hz (interval: ~50ms). Magnitude is computed using Euclidean vector norm:
  $$\text{gForce} = \frac{\sqrt{x^2 + y^2 + z^2}}{9.81}$$
  Maintained inside a 1000ms rolling window to track peak impact.
- **Gyroscope**: Sampled at 20–50 Hz. Computes rotational velocity in degrees per second (°/s):
  $$\text{degPerSec} = \sqrt{\omega_x^2 + \omega_y^2 + \omega_z^2} \times \frac{180}{\pi}$$
  Gracefully handles devices lacking hardware gyroscopes.
- **GPS Telemetry**: High-accuracy position listener calculating speed drop ($\Delta v$ in km/h) over a 2000ms sliding history.

### 2.2 2-of-3 Rule-Based Decision Logic
A crash event is identified when at least **2 of 3** criteria are met within the rolling 1-second window:
1. **Impact Spike**: Resultant G-force $\ge 3.5\text{G}$ (configurable 2.0–5.0G).
2. **Rotational Spike**: Angular velocity $\ge 250^\circ/\text{s}$ (sudden spin, flip, or rollover).
3. **Severe Deceleration**: Speed drops by $\ge 40\text{ km/h}$ within 1–2 seconds.

*Hardware Fallback*: If the device lacks a gyroscope, the detector shifts to a 2-of-2 evaluation (Accelerometer + GPS speed drop).

### 2.3 Post-Detection Cooldown & Debouncing
After a crash is detected, the detector triggers a cooldown timer (default: 60,000ms) to prevent duplicate triggering from subsequent vehicle motion or towing.

---

## 3. False-Positive Filtering (Machine Learning)

To differentiate between real vehicle impacts and benign spikes (e.g. dropping phone on floor, jogging, abrupt speed bumps, or swinging the device), the system incorporates an ML classification layer (`MlCrashClassifier`):
- **Features Extracted**:
  - `peak_g`: Maximum G-force during collision window.
  - `angular_velocity_dps`: Rotational speed in °/s.
  - `speed_drop_kmh`: Observed vehicle deceleration.
  - `post_impact_variance`: Accelerometer variance in the post-impact window (crashes typically exhibit near-zero motion after impact due to immobilization, whereas drops or walking show continued movement).
- **Inference**: Normalized logistic regression model outputting crash probability $P \in [0, 1]$ evaluated with decision threshold 0.50.

---

## 4. Emergency Escalation Protocol

1. **Phase 1: Confirmation Window (0–30 Seconds)**
   - Visual countdown with pulsing radar animation.
   - Device emits heavy haptic pulses and alert audio.
   - User can tap "I'M OK — CANCEL" at any point, which logs the incident as `cancelled`.

2. **Phase 2: Automated Dispatch (30+ Seconds)**
   - **Emergency Dialer**:
     - *Android*: Triggers direct dialer to emergency services (e.g. 112 / 108 / 911) using `tel:` scheme.
     - *iOS*: Opens native dialer pre-filled with single-tap confirmation per Apple platform policy.
   - **Emergency SMS**:
     - Dispatches native SMS intent containing reverse-geocoded location and Google Maps URL to all saved contacts.
     - If device cannot open native SMS (no SIM card, tablet, emulator), dispatches via backend Twilio client.
   - **Nearest Emergency Infrastructure**:
     - Queries local police stations and hospitals within a 5 km radius via backend Google Places proxy / fallback service.
     - Displays directions and contact options on the interactive live map.

3. **Phase 3: Backend Synchronization**
   - Posts comprehensive incident record containing timestamp, GPS coordinates, reverse-geocoded address, sensor telemetry snapshot, notified contacts, and status to `POST /incidents`.

---

## 5. Storage & Database Schema

### 5.1 Mobile Client (SQLite)
- `contacts`: `id (TEXT PK)`, `name (TEXT)`, `phone (TEXT)`, `relation (TEXT)`
- `incidents`: `id (TEXT PK)`, `timestamp (TEXT)`, `lat (REAL)`, `lng (REAL)`, `address (TEXT)`, `status (TEXT)`, `sensor_snapshot (TEXT/JSON)`, `contacts_notified (TEXT/JSON)`, `emergency_call_placed (INTEGER)`

### 5.2 Cloud Backend (SQLAlchemy / SQLite & PostgreSQL)
- `users`: User emergency profile, blood group, allergies, medical notes.
- `contacts`: Synchronized contact list.
- `incidents`: Central audit log of all triggered and cancelled crash events.

---

## 6. Security & Privacy

- **On-Device First**: Sensor monitoring and crash decisions are executed 100% on-device. No raw sensor streams leave the device.
- **Authentication**: Backend API endpoints protected by `X-API-Key` headers in production mode.
- **Selective Sharing**: Location data is transmitted only upon confirmed crash events or explicit user map interaction.
