# Geocode.xyz API details

Endpoint: `https://geocode.xyz/` (GET or POST). Human docs: https://geocode.xyz/api. Examples: https://geocode.xyz/examples.html.

<!-- TODO(Geolytica): publish an OpenAPI spec and SKILL.md at geocode.xyz (as geocoder.ca does) and reconcile this file against it. -->

## Request forms

| Form | Use |
|---|---|
| `https://geocode.xyz/?locate=<input>&json=1` | Preferred; safe for long input |
| `https://geocode.xyz/<input>?json=1` | Path form; may hit "file name too long" |
| POST `locate=` / `scantext=` | Long text, geoparsing |

`locate` accepts a street address, postcode, landmark, city, IPv4 address, or a `lat,lon` pair (reverse geocoding, latitude first). Degree-minute-second notation is also parsed.

## Output

| Parameter | Effect |
|---|---|
| `json=1` | JSON (recommended) |
| `json=1&callback=fn` | JSONP |
| `geojson=1` | GeoJSON |
| `geoit=XML` | XML |
| `geoit=CSV` | CSV: status, confidence, latitude, longitude |

## Optional parameters

| Parameter | Meaning |
|---|---|
| `auth` | API key |
| `region` | Country code(s), comma-separated, or `Europe`, `Asia`, `Oceania`, `SouthAmerica`. UK is `UK`. For North America use `US,CA,MX` |
| `citybias` | Comma-separated city names to bias toward (combine with `region`) |
| `strictmode=1` | Reverse: core address only, skip admin areas and POI (faster) |
| `nostrict=1` | Return low-confidence matches too (noisy in geoparsing) |
| `moreinfo=1` | Add timezone and elevation |
| `sentiment=1` | Sentiment analysis in geoparsing mode |
| `lang` | Language for admin-area names (e.g. `lang=en`) |
| `id` | Your transaction id (≤15 bytes), echoed back |
| `geonumber` | Return the centre of a 10 m cell by its geonumber |

## Autocomplete

`region` (required, two-letter), `streetname` (partial street or postcode), optional `cityname`, `geoit=json`.

Response: `standard.street` is an object keyed by suggestion text; each value has `city`, `post`, `street`, `num`, `score` (higher is better). `matches` is the count. The response also contains `error.code = "008"` and a `suggestion` — this is expected for autocomplete.

## Response fields

| Field | Meaning |
|---|---|
| `latt`, `longt` | Latitude, longitude |
| `elevation`, `timezone` | With `moreinfo=1` |
| `standard.stnumber`, `.addresst`, `.city`, `.prov`, `.postal`, `.countryname`, `.confidence` | Standardized address (`prov` = country code) |
| `stnumber`, `staddress`, `city`, `prov`, `countryname`, `confidence` | Same, top-level variant |
| `geocode`, `altgeocode`, `geonumber` | Identifiers of the 10 m × 10 m cell |
| `MentionIndices`, `matchtype` | Geoparsing: offsets in the input text and match type |
| `inlatt`, `inlongt`, `distance` | Reverse: input point and distance (km) to the result |
| `poi` | Nearest OpenStreetMap point of interest, with `poidist` (km) |
| `osmtags`, `adminareas` | OpenStreetMap admin tags / full admin hierarchy |
| `class` | Road class or speed limit from OSM `maxspeed` |
| `NearRoad`, `NearRoadDistance` | Nearest road and its distance (km) |
| `error.code`, `error.description` | See SKILL.md |
| `suggestion.locate`, `suggestion.region` | Retry hint on no-match |

<!-- TODO(Geolytica): document the exact JSON container for multiple geoparsing matches (array name and per-match fields). -->

## Batch

Web batch tool: https://geocode.xyz/batch — upload a text file with one location per line; output columns are input line, street number, address, city, country, postcode, latitude, longitude, confidence.
