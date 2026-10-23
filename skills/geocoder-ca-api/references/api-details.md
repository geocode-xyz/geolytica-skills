# Geocoder.ca API details

Endpoint: `https://geocoder.ca/` (GET or POST). Authoritative spec: https://geocoder.ca/openapi.json. Human docs: https://geocoder.ca/api.

<!-- TODO(Geolytica): reconcile this file against openapi.json before publishing; it was assembled from SKILL.md and the public docs. -->

## Output selection (send on every request)

| Parameter | Value | Effect |
|---|---|---|
| `geoit` | `XML` | Machine output (required; without it you get an HTML page) |
| `json` | `1` | With `geoit=XML`, return JSON instead of XML |
| `callback` | name | With `json=1`, return JSONP |
| `geoit` | `CSV` | CSV output |
| `auth` | token | Your API token (from `GEOCODER_CA_AUTH`) |

## Forward geocoding

| Parameter | Meaning |
|---|---|
| `locate` | Free-form address, postal code, ZIP/ZIP+4, intersection ("a & b city"), or place |
| `addresst`, `stno`, `city`, `prov`, `postal` | Structured alternative to `locate` |
| `standard=1` | Return standardized components in `standard{}` |
| `showpostal=1` | Include the postal code |
| `getpolygon=1` | With a postal code, include its boundary polygon |
| `country=canada` / `region=ON` | Restrict or bias to a country or province/state |
| `strictmode=1` | Return suggestions rather than a best guess on ambiguous input |
| `id` | Your own transaction id, echoed back |

## Reverse geocoding

| Parameter | Meaning |
|---|---|
| `latt`, `longt` | Point (latitude first) |
| `reverse=1` | Reverse lookup |
| `allna=1` | Search all of North America (required for US points) |
| `corner=1` | Include the nearest intersection |
| `moreinfo=1` | County, metro area and extra context |
| `pois=1` | Nearby places; refine with `type=`, `keyword=`, `radius=` (metres) |

## Intersections

`street1`, `street2`, `city`, `prov`, `cross=1` — or `locate=street1 & street2 city`.

## Geoparsing

`scantext=<text>` (POST for long text). Results in `match[]`, ordered by `confidence` descending, each with `latt`, `longt`, `stnumber`, `staddress`, `city`, `prov`, `country`, `confidence`.

## Premium functions (billed per item)

| Parameter | Returns |
|---|---|
| `autocomplete=1&locate=<partial>` | Canadian address suggestions |
| `showaddrs=1` | Addresses for a postal code |
| `batchpostal=` | Several postal codes in one call |
| `postalinpolygon=` | Postal codes inside a polygon |
| `censusdatafromdauid=<dauid>` | Statistics Canada census data for a dissemination area |

Always pass `limit` with these and confirm the expected cost with the user first.

## Response fields

| Field | Notes |
|---|---|
| `latt`, `longt` | Strings; empty when there is no match |
| `postal` | Canadian postal code or US ZIP |
| `standard.stnumber`, `standard.staddress`, `standard.city`, `standard.prov` | Standardized address |
| `standard.confidence` | 0–1 as a string; below 0.5 is not returned |
| `more` | Unused input (unit, PO box) — keep it |
| `Dissemination_Area.dauid`, `.adauid` | Statistics Canada DA and aggregate DA ids (Canada) |
| `suggestion` | Present on no-match or ambiguous input |
| `error.code`, `error.message` | See the error table in SKILL.md |

Canadian results can also include Alberta Township System / Dominion Land Survey legal subdivisions (LSD), time zone and telephone area code.

## Coordinate system

WGS 84 decimal degrees.
