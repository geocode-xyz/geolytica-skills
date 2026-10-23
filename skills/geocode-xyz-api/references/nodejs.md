# Geocode.xyz from Node.js

```js
const BASE = "https://geocode.xyz/";
const AUTH = process.env.GEOCODE_XYZ_AUTH; // undefined -> shared free port

const clean = (v) => (v && typeof v === "object" && !Object.keys(v).length ? "" : v ?? "");

async function call(params, method = "GET") {
  const p = new URLSearchParams({ json: "1", ...params });
  if (AUTH) p.set("auth", AUTH);
  const res = method === "POST"
    ? await fetch(BASE, { method: "POST", body: p })
    : await fetch(`${BASE}?${p}`);
  if (!res.ok) throw new Error(`HTTP ${res.status}`);
  return res.json();
}

export async function geocode(location, region, { minConfidence = 0.8, retried = false } = {}) {
  const d = await call({ locate: location, ...(region ? { region } : {}) });

  if (d.error) {
    const s = d.suggestion;
    if (d.error.code === "008" && s?.locate && !retried) {
      return geocode(s.locate, s.region || region, { minConfidence, retried: true });
    }
    if (d.error.code === "008") return null;
    const e = new Error(`${d.error.code}: ${d.error.description}`);
    e.code = d.error.code;
    throw e;
  }

  const lat = parseFloat(d.latt), lon = parseFloat(d.longt);
  if (!lat && !lon) return null;
  const std = d.standard || {};
  const pick = (k, alt = k) => clean(std[k]) || clean(d[alt]);
  const confidence = parseFloat(pick("confidence") || "0");
  return {
    lat, lon,
    number: pick("stnumber"),
    street: pick("addresst", "staddress"),
    city: pick("city"),
    postal: pick("postal"),
    countryCode: pick("prov"), // country code, not province
    country: pick("countryname"),
    confidence,
    needsReview: confidence < minConfidence,
  };
}

export const reverse = (lat, lon) => call({ locate: `${lat},${lon}`, strictmode: "1" });

export const geoparse = (text, region) =>
  call({ scantext: text, ...(region ? { region } : {}) }, "POST");

export async function autocomplete(partial, region, city) {
  const d = await call({ streetname: partial, region, geoit: "json", ...(city ? { cityname: city } : {}) });
  const streets = d.standard?.street || {};
  return Object.entries(streets)
    .map(([text, v]) => ({ text, ...v }))
    .sort((a, b) => Number(b.score) - Number(a.score));
}
```

Notes:
- Keep the key on the server. If you need autocomplete in a browser, proxy it through your backend.
- Don't fan out with `Promise.all` on the free port; with a key, cap concurrency to stay under 10 requests per second.
