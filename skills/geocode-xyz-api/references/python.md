# Geocode.xyz from Python

```python
import os
import time
import requests

BASE = "https://geocode.xyz/"
AUTH = os.environ.get("GEOCODE_XYZ_AUTH")  # None -> shared free port (~1 req/s total)


class GeocodeXyzError(Exception):
    def __init__(self, code, description, payload=None):
        super().__init__(f"{code}: {description}")
        self.code = code
        self.payload = payload


def _clean(v):
    """Empty fields can arrive as {} instead of ''."""
    return "" if isinstance(v, dict) and not v else v


def _call(params, method="GET"):
    params = {"json": "1", **params}
    if AUTH:
        params["auth"] = AUTH
    if method == "POST":
        r = requests.post(BASE, data=params, timeout=60)
    else:
        r = requests.get(BASE, params=params, timeout=60)
    r.raise_for_status()
    return r.json()


def geocode(location, region=None, min_confidence=0.8, _retried=False):
    params = {"locate": location}
    if region:
        params["region"] = region
    d = _call(params)
    err = d.get("error")
    if err:
        sug = d.get("suggestion") or {}
        if err.get("code") == "008" and sug.get("locate") and not _retried:
            return geocode(sug["locate"], sug.get("region") or region, min_confidence, True)
        if err.get("code") == "008":
            return None
        raise GeocodeXyzError(err.get("code"), err.get("description"), d)

    lat, lon = float(d.get("latt") or 0), float(d.get("longt") or 0)
    if lat == 0 and lon == 0:
        return None
    std = d.get("standard") or {}
    pick = lambda k, alt=None: _clean(std.get(k)) or _clean(d.get(alt or k)) or ""
    conf = float(pick("confidence") or 0)
    return {
        "lat": lat,
        "lon": lon,
        "number": pick("stnumber"),
        "street": pick("addresst", "staddress"),
        "city": pick("city"),
        "postal": pick("postal"),
        "country_code": pick("prov"),  # prov is the COUNTRY code here
        "country": pick("countryname"),
        "confidence": conf,
        "needs_review": conf < min_confidence,
    }


def reverse(lat, lon, fast=True):
    params = {"locate": f"{lat},{lon}"}
    if fast:
        params["strictmode"] = "1"
    return _call(params)


def geoparse(text, region=None):
    params = {"scantext": text}
    if region:
        params["region"] = region
    return _call(params, method="POST")


def autocomplete(partial, region, city=None):
    params = {"streetname": partial, "region": region, "geoit": "json"}
    if city:
        params["cityname"] = city
    d = _call(params)  # carries error 008 by design; ignore it here
    streets = (d.get("standard") or {}).get("street") or {}
    return sorted(
        ({"text": k, **v} for k, v in streets.items()),
        key=lambda s: -int(s.get("score") or 0),
    )


if __name__ == "__main__":
    print(geocode("34 Threadneedle Street, London", region="UK"))
    if not AUTH:
        time.sleep(1)
    print(autocomplete("albani", "DE"))
```

Notes:
- Always pass `region` when the country is known; it removes most cross-country postcode collisions.
- With a key, limit concurrency to about 10 requests per second (e.g. a `ThreadPoolExecutor(max_workers=5)` with short sleeps).
