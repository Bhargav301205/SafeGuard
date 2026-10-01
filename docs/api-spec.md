# SafeGuard API Specification

## Base URL
```
http://localhost:8000        (development)
https://api.safeguard.app   (production)
```

## Authentication
All endpoints require the `X-API-Key` header in production.  
In development (`DEBUG=true`), this header is optional.

```
X-API-Key: changeme-dev-key
```

---

## Incidents

### POST /incidents
Log a new crash incident.

**Request body:**
```json
{
  "id": "uuid-string",
  "timestamp": "2024-01-15T10:30:00Z",
  "lat": 17.385044,
  "lng": 78.486671,
  "address": "MG Road, Hyderabad, Telangana, India",
  "status": "confirmed",
  "sensorSnapshot": {
    "gForce": 4.2,
    "rotationRate": 310.5,
    "speedDelta": 45.0,
    "timestamp": "2024-01-15T10:30:00Z"
  },
  "contactsNotified": ["+919876543210"],
  "emergencyCallPlaced": true
}
```

**Response:** `201 Created` with full incident object including `mapsUrl`.

---

### GET /incidents
List all incidents, newest first.

**Query params:**
- `skip` (int, default 0)
- `limit` (int, default 50)

---

### GET /incidents/{id}
Retrieve a single incident by UUID.

---

## Contacts

### POST /contacts
Add or update (upsert by ID) an emergency contact.

**Request body:**
```json
{
  "id": "uuid-string",
  "name": "Ananya Sharma",
  "phone": "+919876543210",
  "relation": "Mother"
}
```

---

### GET /contacts
List all saved emergency contacts.

---

### DELETE /contacts/{id}
Remove an emergency contact. Returns `204 No Content`.

---

## Services

### GET /services/nearest
Find nearby emergency facilities via Google Places API.

**Query params:**
- `lat` (float, required)
- `lng` (float, required)
- `type` (string: `police` | `hospital` | `fire`, default `police`)
- `limit` (int 1–10, default 3)

**Response:**
```json
[
  {
    "name": "Hyderabad City Police",
    "address": "Basheerbagh, Hyderabad",
    "lat": 17.3940,
    "lng": 78.4754,
    "distance_km": 1.2
  }
]
```

Returns `[]` when no Google Maps API key is configured.

---

## Health

### GET /health
```json
{ "status": "ok", "service": "SafeGuard API" }
```

---

## User Profile

### GET /user/profile
Retrieve the user's emergency profile.

**Response:** `200 OK`
```json
{
  "id": "default",
  "name": "Sarah Connor",
  "phone": "+919876543299",
  "blood_group": "O+",
  "allergies": "Penicillin",
  "medical_notes": "Asthmatic, carry inhaler",
  "emergency_contacts": ["+919876543210"]
}
```

---

### POST /user/profile
Create or update the user's emergency and medical profile.

**Request body:**
```json
{
  "name": "Sarah Connor",
  "phone": "+919876543299",
  "blood_group": "O+",
  "allergies": "Penicillin",
  "medical_notes": "Asthmatic, carry inhaler",
  "emergency_contacts": ["+919876543210"]
}
```

**Response:** `200 OK` with updated profile object.
