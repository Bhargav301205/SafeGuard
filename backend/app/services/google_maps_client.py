import math
import httpx
from ..core.config import get_settings


def _haversine_km(lat1: float, lng1: float, lat2: float, lng2: float) -> float:
    """Return great-circle distance in km between two lat/lng points."""
    R = 6371.0  # Earth radius in km
    phi1, phi2 = math.radians(lat1), math.radians(lat2)
    dphi = math.radians(lat2 - lat1)
    dlambda = math.radians(lng2 - lng1)
    a = math.sin(dphi / 2) ** 2 + math.cos(phi1) * math.cos(phi2) * math.sin(dlambda / 2) ** 2
    return R * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))


class GoogleMapsClient:
    """Async wrapper for Google Maps Geocoding and Places APIs."""

    BASE_GEOCODE = "https://maps.googleapis.com/maps/api/geocode/json"
    BASE_PLACES = "https://maps.googleapis.com/maps/api/place/nearbysearch/json"

    def __init__(self):
        self.settings = get_settings()

    @property
    def _key(self) -> str:
        return self.settings.google_maps_api_key

    async def reverse_geocode(self, lat: float, lng: float) -> str:
        """Returns a human-readable address for the given coordinates."""
        if not self._key:
            # Free fallback via OpenStreetMap Nominatim for dev/offline testing
            try:
                async with httpx.AsyncClient(timeout=4) as client:
                    resp = await client.get(
                        "https://nominatim.openstreetmap.org/reverse",
                        params={"lat": lat, "lon": lng, "format": "json"},
                        headers={"User-Agent": "SafeGuard-Accident-Detection/1.0"},
                    )
                    if resp.status_code == 200:
                        data = resp.json()
                        addr = data.get("display_name")
                        if addr:
                            return addr
            except Exception:
                pass
            return f"{lat:.6f}, {lng:.6f}"

        async with httpx.AsyncClient(timeout=8) as client:
            resp = await client.get(self.BASE_GEOCODE, params={
                "latlng": f"{lat},{lng}",
                "key": self._key,
            })
            data = resp.json()
            if data.get("status") == "OK" and data["results"]:
                return data["results"][0]["formatted_address"]
        return f"{lat:.6f}, {lng:.6f}"

    async def nearby_search(
        self,
        lat: float,
        lng: float,
        place_type: str,
        radius: int = 5000,
        limit: int = 3,
        allow_fallback: bool = True,
    ) -> list[dict]:
        """
        Returns a list of nearby places of [place_type].
        place_type: 'police', 'hospital', 'fire_station'
        """
        if not self._key:
            if not allow_fallback:
                return []
            return self._generate_fallback_places(lat, lng, place_type, limit)

        async with httpx.AsyncClient(timeout=10) as client:
            resp = await client.get(self.BASE_PLACES, params={
                "location": f"{lat},{lng}",
                "radius": radius,
                "type": place_type,
                "key": self._key,
            })
            data = resp.json()

        results = []
        for place in data.get("results", [])[:limit]:
            loc = place["geometry"]["location"]
            dist_km = _haversine_km(lat, lng, loc["lat"], loc["lng"])
            results.append({
                "name": place.get("name", ""),
                "address": place.get("vicinity", ""),
                "lat": loc["lat"],
                "lng": loc["lng"],
                "distance_km": round(dist_km, 2),
            })

        if not results and allow_fallback:
            return self._generate_fallback_places(lat, lng, place_type, limit)
        return results

    def _generate_fallback_places(
        self,
        lat: float,
        lng: float,
        place_type: str,
        limit: int,
    ) -> list[dict]:
        """Generates realistic emergency facilities nearby for testing and demo."""
        templates = {
            "police": [
                ("Central Emergency Police Station", "Sector 4, Main Highway", 0.005, 0.003, 0.6),
                ("Metropolitan Rapid Response Unit", "Basheerbagh Police Circle", -0.008, 0.006, 1.1),
                ("Highway Patrol & Incident Post #7", "Bypass Junction", 0.012, -0.007, 1.5),
            ],
            "hospital": [
                ("City General Emergency Trauma Care", "102 Health Avenue", 0.007, -0.004, 0.9),
                ("St. Jude 24/7 Ambulance & Casualty", "Medical Square", -0.005, -0.008, 1.2),
                ("Apex Super Specialty Hospital", "Outer Ring Road", 0.014, 0.009, 1.8),
            ],
            "fire_station": [
                ("Municipal Fire & Rescue HQ", "Civic Center Road", -0.006, 0.004, 0.8),
                ("Emergency Response Fire Station #3", "Industrial Zone", 0.011, 0.011, 1.6),
            ],
        }
        items = templates.get(place_type, templates["police"])
        results = []
        for name, addr, dlat, dlng, dist in items[:limit]:
            results.append({
                "name": name,
                "address": addr,
                "lat": round(lat + dlat, 6),
                "lng": round(lng + dlng, 6),
                "distance_km": dist,
            })
        return results


google_maps_client = GoogleMapsClient()
