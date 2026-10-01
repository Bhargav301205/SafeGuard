import unittest
from starlette.testclient import TestClient
from app.main import app
import uuid

import asyncio
from app.db.database import init_db

class TestSafeGuardAPI(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        asyncio.run(init_db())

    def setUp(self):
        self.client = TestClient(app)

    def test_01_health_check(self):
        response = self.client.get("/health")
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json(), {"status": "ok", "service": "SafeGuard API"})

    def test_02_contacts_crud(self):
        contact_id = str(uuid.uuid4())
        payload = {
            "id": contact_id,
            "name": "Integration Test Contact",
            "email": "guardian@safeguard.local",
            "phone": "+919876543210",
            "relation": "Guardian"
        }
        # Create
        create_res = self.client.post("/contacts", json=payload)
        self.assertEqual(create_res.status_code, 201)
        data = create_res.json()
        self.assertEqual(data["name"], "Integration Test Contact")
        self.assertEqual(data["email"], "guardian@safeguard.local")
        self.assertEqual(data["id"], contact_id)

        # List
        list_res = self.client.get("/contacts")
        self.assertEqual(list_res.status_code, 200)
        items = list_res.json()
        saved = next((c for c in items if c["id"] == contact_id), None)
        self.assertIsNotNone(saved)
        self.assertEqual(saved["email"], "guardian@safeguard.local")

        # Delete
        del_res = self.client.delete(f"/contacts/{contact_id}")
        self.assertEqual(del_res.status_code, 204)

    def test_03_incidents_create_and_get(self):
        incident_id = str(uuid.uuid4())
        payload = {
            "id": incident_id,
            "timestamp": "2026-09-18T10:30:00Z",
            "lat": 17.385044,
            "lng": 78.486671,
            "address": "MG Road, Hyderabad, Telangana, India",
            "status": "confirmed",
            "sensorSnapshot": {
                "gForce": 4.5,
                "rotationRate": 290.0,
                "speedDelta": 42.0,
                "timestamp": "2026-09-18T10:30:00Z"
            },
            "contactsNotified": ["+919876543210"],
            "emergencyCallPlaced": True
        }

        # Create
        res = self.client.post("/incidents", json=payload)
        self.assertEqual(res.status_code, 201)
        data = res.json()
        self.assertEqual(data["id"], incident_id)
        self.assertEqual(data["mapsUrl"], "https://maps.google.com/?q=17.385044,78.486671")

        # Get list
        list_res = self.client.get("/incidents")
        self.assertEqual(list_res.status_code, 200)
        incidents = list_res.json()
        self.assertTrue(any(i["id"] == incident_id for i in incidents))

        # Get detail
        detail_res = self.client.get(f"/incidents/{incident_id}")
        self.assertEqual(detail_res.status_code, 200)
        detail = detail_res.json()
        self.assertEqual(detail["id"], incident_id)
        self.assertEqual(detail["sensorSnapshot"]["gForce"], 4.5)

    def test_04_nearest_services(self):
        res = self.client.get("/services/nearest?lat=17.385044&lng=78.486671&type=police")
        self.assertEqual(res.status_code, 200)
        places = res.json()
        self.assertIsInstance(places, list)
        self.assertGreater(len(places), 0)
        self.assertIn("name", places[0])
        self.assertIn("distance_km", places[0])

    def test_05_user_profile_crud(self):
        # Initial get profile
        get_res = self.client.get("/user/profile")
        self.assertEqual(get_res.status_code, 200)
        data = get_res.json()
        self.assertEqual(data["id"], "default")

        # Save profile
        profile_data = {
            "name": "Sarah Connor",
            "phone": "+919876543299",
            "blood_group": "O+",
            "allergies": "Penicillin",
            "medical_notes": "Asthmatic, carry inhaler",
            "emergency_contacts": ["+919876543210"],
        }
        post_res = self.client.post("/user/profile", json=profile_data)
        self.assertEqual(post_res.status_code, 200)
        saved = post_res.json()
        self.assertEqual(saved["name"], "Sarah Connor")
        self.assertEqual(saved["blood_group"], "O+")

        # Retrieve updated profile
        get_again = self.client.get("/user/profile")
        self.assertEqual(get_again.status_code, 200)
        self.assertEqual(get_again.json()["allergies"], "Penicillin")

    def test_06_incident_with_automatic_contact_notification(self):
        # 1. Save a contact in DB
        cid = str(uuid.uuid4())
        self.client.post("/contacts", json={
            "id": cid,
            "name": "Auto Notify Guardian",
            "phone": "+919123456789",
            "relation": "Father"
        })

        # 2. Post incident with empty contactsNotified — should fallback to DB contacts
        inc_id = str(uuid.uuid4())
        res = self.client.post("/incidents", json={
            "id": inc_id,
            "timestamp": "2026-09-18T10:35:00Z",
            "lat": 17.385044,
            "lng": 78.486671,
            "address": "HiTech City, Hyderabad",
            "status": "confirmed",
            "sensorSnapshot": {
                "gForce": 4.8,
                "rotationRate": 320.0,
                "speedDelta": 50.0,
                "timestamp": "2026-09-18T10:35:00Z"
            },
            "contactsNotified": [],
            "emergencyCallPlaced": True
        })
        self.assertEqual(res.status_code, 201)
        data = res.json()
        self.assertEqual(data["id"], inc_id)
        # Cleanup contact
        self.client.delete(f"/contacts/{cid}")

if __name__ == "__main__":
    unittest.main()
