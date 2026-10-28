---
name: geocode-xyz-api
description: Geocode and reverse geocode addresses, postcodes, landmarks and IP addresses worldwide, extract (geoparse) every location mentioned in free text, and autocomplete street names and postcodes using the Geocode.xyz API. Use whenever a task involves locations outside Canada and the USA, international or mixed-country address data, finding place names in documents or social posts, or looking up the country, admin areas, timezone or elevation for a coordinate.
---

# Geocode.xyz API

Geocode.xyz is a worldwide geocoding and geoparsing API run by the same company as Geocoder.ca. Every function uses one HTTPS endpoint, `https://geocode.xyz/`, via GET or POST. Human docs: https://geocode.xyz/api.

For addresses known to be in Canada or the USA, prefer the `geocoder-ca-api` skill: it adds postal-code standardization, ZIP+4 and census geography. For mixed data, route each record by country.

## Making requests yourself: use the bundled script

When you need to call the API directly (to answer a question, check an address, test something), run `scripts/geocode_xyz.sh` from this skill's base directory, using its absolute path, with each parameter as a `name=value` argument:

```bash
<skill-dir>/scripts/geocode_xyz.sh 'locate=10 Downing St, London' region=UK
<skill-dir>/scripts/geocode_xyz.sh 'locate=51.5034,-0.1276' moreinfo=1
```

The script URL-encodes every argument, adds `json=1` (unless you pass `geojson=` or `geoit=`), sends `scantext=` as POST, and adds `auth=` from `GEOCODE_XYZ_AUTH` when it is set, so you never need to check for the key or write `$GEOCODE_XYZ_AUTH` in a command (agent permission checks block commands that expand unknown variables). Never pass `auth=` yourself. If the script reports that `GEOCODE_XYZ_AUTH` is not set, the request used the shared free port.

The raw `curl` examples below are for code you write into the user's project, not for your own lookups.

## Authentication and limits

- Pass the user's key as `auth=KEY`. Read it from the `GEOCODE_XYZ_AUTH` environment variable if set; never hard-code, print or commit it. The bundled script does this for you.
- Without a key, requests share a free port throttled to about one request per second across all unauthenticated users combined, so expect slow or throttled (`006`) responses. Do not run batches on it.
- With a key, stay at or under 10 requests per second.
- For large volumes, suggest https://geocode.xyz/batch, a plan at https://geocode.xyz/pricing, or the self-hosted AWS Marketplace AMI.

## Request format

Always use the parameter form, not the path form, so long or unusual input doesn't break the URL:

```bash
curl -sG 'https://geocode.xyz/' \
  --data-urlencode 'locate=Hauptstr., 57632 Berzhausen' \
  --data 'region=DE' --data 'json=1' --data "auth=$GEOCODE_XYZ_AUTH"
```

Output: `json=1` (recommended), `geojson=1`, `geoit=XML` or `geoit=CSV`. Omitting all of them returns an HTML page. Treat numeric values as strings and convert them.

## Common tasks

**Forward geocode.** `locate=<address, postcode, landmark or city>`. Add `region=` whenever the country is known: the same postcode or street can exist in several countries (e.g. `04548-005` is a valid format in Luxembourg, Brazil and New Zealand; without `region` you get a single low-confidence guess, which in testing was Brazil at 0.2). `region` takes ISO-style two-letter codes — the UK is `UK` (`GB` also worked in testing) — comma-separated lists (`region=UK,FR`), or `Europe`, `Asia`, `Oceania`, `SouthAmerica`. `citybias=<city,city>` further biases toward named cities.

**Reverse geocode.** `locate=<lat>,<lon>` — latitude first. Add `moreinfo=1` for timezone and elevation, or `strictmode=1` to skip admin areas and POI lookup when you only need the address (faster).

**IP geolocation.** `locate=<IPv4 address>`. The response looks like a full street address (`8.8.8.8` returned a street in Tampa, confidence 0.6), but IP location is city-level at best and wrong for anycast addresses; use only the city and country.

**Geoparse text.** POST `scantext=<text>`; every location found is returned, ordered by confidence, with `MentionIndices` (character offsets in your text) and `matchtype` (street, intersection, locality, landmark, postcode). Add `region=` to cut false positives, `nostrict=1` to include low-confidence matches, `sentiment=1` for sentiment analysis. `MentionIndices` lists the character offsets of the words that matched (e.g. `"57,60,71"` for "24", "Sussex" and "Ottawa" in "24 Sussex Dr, Ottawa"); the first is where the mention starts. Words the geocoder normalises or skips, such as street types ("Dr", "Ave") and directionals ("NW"), are not listed, so extend the span to the last listed word's end when highlighting text. The top-level `latt`/`longt` of a geoparse response is a centroid, by design: the confidence-weighted mean of the matches at confidence 0.5 or higher, or `0.00000,0.00000` when none reach 0.5. It shows where the reliable mentions cluster, which is useful when they are all in one city block or neighbourhood. When matches are far apart it can fall somewhere none of them is (Washington DC + Ottawa gives a point in upstate New York), so take each location's coordinates from `match[]` and use the centroid only as a cluster indicator. City names that appear only inside a street match ("Vienna" in "Albertinaplatz, Vienna") are not returned separately.

```bash
curl -s https://geocode.xyz/ \
  --data-urlencode 'scantext=The most important museums of Amsterdam are on the Museumplein.' \
  --data 'region=NL' --data 'json=1' --data "auth=$GEOCODE_XYZ_AUTH"
```

**Autocomplete streets or postcodes.** `region=DE&streetname=albani&geoit=json` (add `cityname=` to narrow). Suggestions arrive in `standard.street`, keyed by name, each with `city`, `post` (postcode) and `score` (higher is better); `num` and `street` may be empty strings. `matches` is the count, as a string or a number, so convert it. Requests without a key may also carry error code `008` "Your request produced the following suggestions" and a `suggestion` — that is the normal success shape here, not a failure. The top-level `latt`/`longt` are `0.00000` here; there are no coordinates per suggestion, so geocode the chosen one with `locate=` if you need them.

## Interpreting results

- Coordinates are in `latt`/`longt`. Empty or `0.00000` values mean no match. In a geoparse (`scantext`) response, per-location coordinates are in `match[]` and the top-level pair is the confidence-weighted centroid of matches at 0.5 or higher (`0.00000` when there are none).
- **`confidence` of `0` also means no match, even when coordinates are present**: reverse geocoding `0,0` (open ocean) returned Rio Tinto, Portugal, with confidence `0`.
- `confidence` runs 0–1 (1 best) and may be formatted `"1"` or `"1.00"`; compare it as a number. Low-confidence results are returned (0.2 seen in testing). Treat 0.8+ as reliable and show anything lower to the user before relying on it.
- Landmark names can match a street named after them: `Eiffel Tower, Paris` returned a "1 Eiffel" address in Levallois-Perret (postcode 92300), about 3.7 km from the tower, at confidence 0.8. Check landmark results against the known location.
- Non-Latin input: Cyrillic worked; Japanese comes back in the original script (日本橋三丁目, 中央区), though `stnumber` may hold a number the input never gave; an Arabic landmark name returned no result. Keep the user's original text for display.
- Text and postcodes are not normalised consistently: accents can be dropped (`São Paulo` vs `Sao Paulo`) and postcodes reformatted (`04548005` vs `01310-200`). Normalise both before comparing.
- Address components may appear under `standard{}` (`stnumber`, `addresst`, `city`, `prov`, `postal`, `countryname`, `confidence`) or at the top level (`stnumber`, `staddress`, `city`, `prov`, `countryname`). Read `standard` first and fall back to the top level.
- `prov` is the **country** code in Geocode.xyz responses, not a province.
- Empty fields can come back as an empty object `{}` instead of an empty string; normalise them before writing CSV or databases.
- Reverse results add `distance` (km from the input point), the nearest `poi`, `osmtags`/`adminareas` (OpenStreetMap admin hierarchy), `NearRoad` and `NearRoadDistance`.
- `geocode`, `altgeocode` and `geonumber` identify the 10 m × 10 m cell the point falls in; `?geonumber=<n>` returns that cell's centre.

## Errors and suggestions

JSON errors look like `{"error": {"code": "008", "description": "..."}, "suggestion": {"locate": "...", "region": "AU"}}` — the text is in `description`. `suggestion.locate` can be an empty object `{}` (seen for nonsense input and an Arabic place name), so only retry when it is a non-empty string.

| Code | Meaning | What to do |
|---|---|---|
| 002 | Key out of credits | Stop; tell the user to top up |
| 003 | Key not found | Check `GEOCODE_XYZ_AUTH` |
| 005 | Malformed postal code | Fix the format or drop it from `locate` |
| 006 | Throttled | Back off; suggest a key |
| 007 | Invalid query | Check parameters |
| 008 | No results | If `suggestion.locate` is a non-empty string, retry once with it and `suggestion.region` |

Retrying the suggestion with its region usually succeeds; do it at most once per input.

## References

Load only what the task needs:

- `references/api-details.md` — every parameter and response field
- `references/python.md`, `references/nodejs.md`, `references/perl.md`, `references/php.md` — client code with suggestion-retry and error handling
- `references/commandline.md` — curl recipes and batch CSV processing
- `scripts/geocode_xyz.sh` — wrapper for your own lookups (see above)
