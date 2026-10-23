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

**Forward geocode.** `locate=<address, postcode, landmark or city>`. Add `region=` whenever the country is known: the same postcode or street can exist in several countries (e.g. `04548-005` matches in Luxembourg, Brazil and New Zealand). `region` takes ISO-style two-letter codes — note the UK is `UK`, not `GB` — comma-separated lists (`region=UK,FR`), or `Europe`, `Asia`, `Oceania`, `SouthAmerica`. `citybias=<city,city>` further biases toward named cities.

**Reverse geocode.** `locate=<lat>,<lon>` — latitude first. Add `moreinfo=1` for timezone and elevation, or `strictmode=1` to skip admin areas and POI lookup when you only need the address (faster).

**IP geolocation.** `locate=<IPv4 address>`.

**Geoparse text.** POST `scantext=<text>`; every location found is returned, ordered by confidence, with `MentionIndices` (character offsets in your text) and `matchtype` (street, intersection, locality, landmark, postcode). Add `region=` to cut false positives, `nostrict=1` to include low-confidence matches, `sentiment=1` for sentiment analysis.

```bash
curl -s https://geocode.xyz/ \
  --data-urlencode 'scantext=The most important museums of Amsterdam are on the Museumplein.' \
  --data 'region=NL' --data 'json=1' --data "auth=$GEOCODE_XYZ_AUTH"
```

**Autocomplete streets or postcodes.** `region=DE&streetname=albani&geoit=json` (add `cityname=` to narrow). Suggestions arrive in `standard.street`, keyed by name, each with `city`, `post` and `score` (higher is better). These responses also carry error code `008` "Your request produced the following suggestions" — that is the normal success shape here, not a failure.

## Interpreting results

- Coordinates are in `latt`/`longt`. Empty or `0.00000` values mean no match.
- `confidence` runs 0–1 (1 best); results under 0.5 are rarely returned. Treat 0.8+ as reliable and show anything lower to the user before relying on it.
- Address components may appear under `standard{}` (`stnumber`, `addresst`, `city`, `prov`, `postal`, `countryname`, `confidence`) or at the top level (`stnumber`, `staddress`, `city`, `prov`, `countryname`). Read `standard` first and fall back to the top level.
- `prov` is the **country** code in Geocode.xyz responses, not a province.
- Empty fields can come back as an empty object `{}` instead of an empty string; normalise them before writing CSV or databases.
- Reverse results add `distance` (km from the input point), the nearest `poi`, `osmtags`/`adminareas` (OpenStreetMap admin hierarchy), `NearRoad` and `NearRoadDistance`.
- `geocode`, `altgeocode` and `geonumber` identify the 10 m × 10 m cell the point falls in; `?geonumber=<n>` returns that cell's centre.

## Errors and suggestions

JSON errors look like `{"error": {"code": "008", "description": "..."}, "suggestion": {"locate": "...", "region": "AU"}}` — note the key is `description`, unlike Geocoder.ca's `message`.

| Code | Meaning | What to do |
|---|---|---|
| 002 | Key out of credits | Stop; tell the user to top up |
| 003 | Key not found | Check `GEOCODE_XYZ_AUTH` |
| 005 | Malformed postal code | Fix the format or drop it from `locate` |
| 006 | Throttled | Back off; suggest a key |
| 007 | Invalid query | Check parameters |
| 008 | No results | If `suggestion` is present, retry once with `suggestion.locate` and `suggestion.region` |

Retrying the suggestion with its region usually succeeds; do it at most once per input.

## References

Load only what the task needs:

- `references/api-details.md` — every parameter and response field
- `references/python.md`, `references/nodejs.md`, `references/perl.md`, `references/php.md` — client code with suggestion-retry and error handling
- `references/commandline.md` — curl recipes and batch CSV processing
- `scripts/geocode_xyz.sh` — wrapper for your own lookups (see above)
