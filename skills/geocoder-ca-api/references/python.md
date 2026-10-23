# Geocoder.ca from Python

No SDK is needed; use `requests` (or `httpx`). Always send `geoit=XML&json=1`, read the token from the environment, and convert numeric strings yourself.

```python
import os
import time
import requests

BASE = "https://geocoder.ca/"
AUTH = os.environ.get("GEOCODER_CA_AUTH")  # None -> free throttled port


class GeocoderCaError(Exception):
    def __init__(self, code, message, payload=None):
        super().__init__(f"{code}: {message}")
        self.code = code
        self.payload = payload


def _call(params, method="GET", retries=1):
    params = {"geoit": "XML", "json": "1", **params}
    if AUTH:
        params["auth"] = AUTH
    for attempt in range(retries + 1):
        if method == "POST":
            r = requests.post(BASE, data=params, timeout=30)
        else:
            r = requests.get(BASE, params=params, timeout=30)
        if r.status_code == 429 and attempt < retries:
            time.sleep(float(r.headers.get("Retry-After", 2)))
            continue
        r.raise_for_status()
        data = r.json()
        err = data.get("error")
        if err:
            raise GeocoderCaError(err.get("code"), err.get("message"), data)
        return data
    raise GeocoderCaError("006", "Throttled; an auth token is needed")


def geocode(address, min_confidence=0.8):
    data = _call({"locate": address, "standard": "1", "showpostal": "1"})
    if not data.get("latt"):
        return None  # no match; inspect data.get("suggestion")
    std = data.get("standard", {})
    conf = float(std.get("confidence", 0) or 0)
    return {
        "lat": float(data["latt"]),
        "lon": float(data["longt"]),
        "postal": data.get("postal"),
        "address": std,
        "confidence": conf,
        "needs_review": conf < min_confidence,
        "unused_input": data.get("more"),
        "dauid": (data.get("Dissemination_Area") or {}).get("dauid"),
    }


def reverse(lat, lon, include_us=True):
    params = {"latt": lat, "longt": lon, "reverse": "1"}
    if include_us:
        params["allna"] = "1"
    return _call(params)


def geoparse(text):
    return _call({"scantext": text}, method="POST").get("match", [])


if __name__ == "__main__":
    print(geocode("330 metcalfe ottawa on"))
```

Notes:
- Without a token, call no faster than one request per second (`time.sleep(1)` between calls).
- Treat `GeocoderCaError` code `008` as "no result", not a failure; `002`/`003` mean the token needs attention and should stop a batch.
- `pandas` users: apply `geocode` row by row with a pause, or use the batch service for large files.
