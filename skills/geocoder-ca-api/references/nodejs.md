# Geocoder.ca from Node.js

Node 18+ has `fetch` built in; no SDK is needed. Keep the token server-side (never ship it to a browser bundle except for the autocomplete widget, which has its own skill).

```js
const BASE = "https://geocoder.ca/";
const AUTH = process.env.GEOCODER_CA_AUTH; // undefined -> free throttled port

class GeocoderCaError extends Error {
  constructor(code, message, payload) {
    super(`${code}: ${message}`);
    this.code = code;
    this.payload = payload;
  }
}

async function call(params, { method = "GET", retries = 1 } = {}) {
  const p = new URLSearchParams({ geoit: "XML", json: "1", ...params });
  if (AUTH) p.set("auth", AUTH);

  for (let attempt = 0; attempt <= retries; attempt++) {
    const res = method === "POST"
      ? await fetch(BASE, { method: "POST", body: p })
      : await fetch(`${BASE}?${p}`);

    if (res.status === 429 && attempt < retries) {
      const wait = Number(res.headers.get("retry-after") || 2) * 1000;
      await new Promise((r) => setTimeout(r, wait));
      continue;
    }
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    const data = await res.json();
    // Most errors use "description"; 006 (throttled) uses "message".
    if (data.error) throw new GeocoderCaError(data.error.code, data.error.description ?? data.error.message, data);
    return data;
  }
  throw new GeocoderCaError("006", "Throttled; an auth token is needed");
}

export async function geocode(address, minConfidence = 0.8) {
  const d = await call({ locate: address, standard: "1", showpostal: "1" });
  if (!d.latt) return null; // no match; see d.suggestion
  const conf = parseFloat(d.standard?.confidence ?? "0");
  return {
    lat: parseFloat(d.latt),
    lon: parseFloat(d.longt),
    postal: d.postal,
    address: d.standard,
    confidence: conf,
    needsReview: conf < minConfidence,
    unusedInput: d.more,
    dauid: d.Dissemination_Area?.dauid,
  };
}

export async function reverse(lat, lon, includeUS = true) {
  return call({ latt: lat, longt: lon, reverse: "1", ...(includeUS ? { allna: "1" } : {}) });
}

export async function geoparse(text) {
  return (await call({ scantext: text }, { method: "POST" })).match ?? [];
}
```

Notes:
- All values come back as strings; `parseFloat` before doing arithmetic.
- Error `008` means no result: return `null` rather than throwing in UI code.
- For many lookups on the free port, run them sequentially with a 1-second delay; do not use `Promise.all`.
