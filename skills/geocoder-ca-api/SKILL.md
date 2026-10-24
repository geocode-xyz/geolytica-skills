---
name: geocoder-ca-api
description: Geocode, reverse geocode, validate and standardize Canadian and U.S. addresses, look up postal codes and ZIP+4, extract locations from free text, and find nearby places using the Geocoder.ca API. Use whenever a task involves turning North American addresses, postal codes or intersections into coordinates (or coordinates into addresses), cleaning address data, or adding Statistics Canada census geography to Canadian addresses.
---

# Geocoder.ca API

Geocoder.ca is a North American (Canada + USA) geocoding API. Every function uses one HTTPS endpoint, `https://geocoder.ca/`, via GET or POST. The machine-readable spec is at https://geocoder.ca/openapi.json and the human docs at https://geocoder.ca/api.

For locations outside Canada and the USA, use the `geocode-xyz-api` skill (https://geocode.xyz) instead. For an as-you-type address field in a web page, use the `geocoder-ca-autocomplete` skill.

## Making requests yourself: use the bundled script

When you need to call the API directly (to answer a question, check an address, test something), run `scripts/geocoder_ca.sh` from this skill's base directory, using its absolute path, with each parameter as a `name=value` argument:

```bash
<skill-dir>/scripts/geocoder_ca.sh 'locate=350 5th Ave, New York, NY' standard=1 showpostal=1
<skill-dir>/scripts/geocoder_ca.sh latt=45.4215 longt=-75.6972 reverse=1 allna=1
```

The script URL-encodes every argument, adds `geoit=XML&json=1`, and adds `auth=` from `GEOCODER_CA_AUTH` when it is set, so you never need to check for the token or write `$GEOCODER_CA_AUTH` in a command (agent permission checks block commands that expand unknown variables). Never pass `auth=` yourself. If the script reports that `GEOCODER_CA_AUTH` is not set, the request used the free port.

The raw `curl` examples below are for code you write into the user's project, not for your own lookups.

## Authentication and limits

- Pass the user's token as `auth=TOKEN`. Read it from the `GEOCODER_CA_AUTH` environment variable if set; never hard-code, print or commit it. The bundled script does this for you.
- Without a token, requests use the free throttled port. Keep to one request at a time with at least a one-second pause, and expect HTTP 429 (error code `006`) if you go faster. On 429, wait (honour `Retry-After` if present) and retry once; if it persists, tell the user a token is needed (https://geocoder.ca/pricing).
- With a token, one successful lookup costs one credit. `showaddrs`, `batchpostal`, `postalinpolygon` and `censusdatafromdauid` bill per returned item, so always set `limit` and confirm with the user before large premium requests.

## Always request JSON

Add `geoit=XML&json=1` to every request. (`geoit=CSV` gives CSV; omitting `geoit` returns an HTML page.) All JSON values, including numbers, are strings: convert `latt`, `longt` and `confidence` with `float()`.

## Common tasks

**Forward geocode / validate an address.** Put everything in `locate`; add `standard=1` for clean components and `showpostal=1` for the postal code.

```bash
curl -sG 'https://geocoder.ca/' \
  --data-urlencode 'locate=330 metcalfe ottawa on' \
  --data 'geoit=XML' --data 'json=1' --data 'standard=1' --data 'showpostal=1' \
  --data "auth=$GEOCODER_CA_AUTH"
```

```json
{"latt":"45.414399","longt":"-75.690474","postal":"K2P1S4",
 "standard":{"stnumber":"330","staddress":"Metcalfe","city":"Ottawa","prov":"ON","confidence":"1"},
 "Dissemination_Area":{"dauid":"35061714","adauid":"35060135"}}
```

**Postal code or ZIP.** `locate=K1A0A6` or `locate=90210-3069`. Add `getpolygon=1` for the postal-code boundary polygon.

**Reverse geocode.** `latt=45.4215&longt=-75.6972&reverse=1`. Add `allna=1` for any point that may be in the USA (recommended; a US point also resolved without it in testing), `corner=1` for the nearest intersection, `moreinfo=1` for county and metro area.

**Nearby places.** A reverse lookup plus `pois=1`, optionally `type=restaurant` or `keyword=Subway` and `radius` in metres. (In testing, `pois=1&radius=300` in central Ottawa returned no place data; if the response has none, tell the user rather than inventing results.)

**Intersection.** `street1=metcalfe&street2=wellington&city=ottawa&prov=ON&cross=1`, or simply `locate=metcalfe & wellington ottawa`. Intersection results come back as top-level `street1`/`street2` (with trailing spaces, e.g. `"Metcalfe ST "`) and no `standard{}`; trim them, and expect the `postal` to be the nearest building's.

**Extract locations from text.** `scantext=` with the text (use POST for long text). Results arrive in `match[]`, highest confidence first; each has `latt`, `longt`, `stnumber`, `staddress`, `city`, `prov`, `country`, `confidence`. Verify matches before using them: in testing, "1600 Pennsylvania Ave NW, Washington DC or to 24 Sussex Dr, Ottawa" found neither address and returned four unrelated matches (confidence 0.5–0.9) built from mixed fragments, such as "18 Sussex Ct, Washington, NJ". Check each match's `city`/`prov` against the text, and ignore the top-level `latt`/`longt` of a geoparse response.

**Census data (Canada).** Take `Dissemination_Area.dauid` from a lookup and request `censusdatafromdauid=<dauid>` (premium, billed per item).

**Autocomplete (premium).** `autocomplete=1&locate=1435 prince` returns Canadian address suggestions for a partial address. For a ready-made browser widget, use the `geocoder-ca-autocomplete` skill.

## Interpreting results

- Empty `latt`/`longt` means no match. Low-confidence results **are** returned (0.1–0.3 seen in testing), so filter on `confidence` yourself; the response may also contain suggestions.
- Treat `confidence` of 0.8 or higher as reliable. Between 0.5 and 0.8, show the matched address to the user before relying on it. Below 0.5, treat the result as no match unless it is a postal-code lookup (next point).
- Postal-code-only lookups (`locate=K1A0A6`) return the code's centroid with low confidence (0.1–0.3) even when the code is valid. Judge them by whether the returned `postal` equals the input, not by `confidence`, and ignore any `standard.stnumber` (`locate=k2p 1s4` came back with `stnumber: "1"`).
- Geocoder.ca does not reject addresses outside Canada and the USA: `10 Downing St, London` returned an invented "10 Street St, London, ON" (confidence 0.2) whose coordinates are about 150 km from London, ON. Route other countries to the `geocode-xyz-api` skill.
- Empty fields can come back as an empty object `{}` instead of `""` (e.g. `standard.stnumber` on a postal-code lookup); normalise them before storing.
- `more` holds input the geocoder did not use (unit numbers, PO boxes); keep it rather than discarding it.
- Ambiguous place names (e.g. a city with no province or state) can resolve to the wrong country. Always include the province/state, or pass `country=canada` or `region=ON`. `strictmode=1` is documented to return suggestions instead of a guess, but in testing `locate=Springfield` returned Springfield, MO at confidence 0.8 with or without it, and no `101` error: don't rely on the API to flag ambiguity.
- Canadian postal codes are `A1A1A1`; accept user input with or without the space and in any case, but send it uppercase.

## Errors

JSON errors look like `{"error": {"code": "008", "description": "..."}}`. Most errors put the text in **`description`**; the throttling error (`006`) uses `message`. Read `error.description` and fall back to `error.message`. Error responses can also contain meaningless `latt`/`longt` values, so ignore coordinates whenever `error` is present.

| Code | Meaning | What to do |
|---|---|---|
| 001 | IP not allowed for this token | Tell the user; the token is IP-restricted |
| 002 | Token out of credits | Tell the user to top up at geocoder.ca/pricing |
| 003 | Token not found | Check `GEOCODER_CA_AUTH` |
| 004 | Invalid province/state code | Use a 2-letter code (ON, QC, NY…). An invalid `prov` on a structured query returned `007` in testing |
| 005 | Malformed postal code | Canadian format is A1A1A1. Also returned for unparseable free text, so treat `005` on input that isn't a postal code as `008` |
| 006 | Throttled | Wait and retry once; suggest a token |
| 007 | Invalid query | Check parameters |
| 008 | No results | Check spelling; use any `suggestion` returned |
| 009 | Lat/long out of range | Check coordinate order (`latt` first) |
| 010 | Intersection incomplete | Supply two streets, city and province |
| 101 | Ambiguous input | Pick from the returned possible cities, or ask the user (not seen in testing; ambiguous city names were resolved silently) |

## Batch work

For more than a few hundred addresses, don't loop over the API on the free port. Suggest the batch tool (https://geocoder.ca/batch), an unlimited plan, or a licensed dataset (https://geocoder.ca/pricing). With a paid token, see `references/commandline.md` for a throttled CSV loop.

## Licensing note

Geocoder.ca results may be stored, cached permanently and displayed on any map. You do not need to add re-fetch or cache-expiry logic for licensing reasons.

## References

Load only what the task needs:

- `references/api-details.md` — every parameter and response field, grouped by task
- `references/python.md`, `references/nodejs.md`, `references/perl.md`, `references/php.md` — idiomatic client code with error handling
- `references/commandline.md` — curl recipes and batch CSV processing
- `scripts/geocoder_ca.sh` — wrapper for your own lookups (see above)
