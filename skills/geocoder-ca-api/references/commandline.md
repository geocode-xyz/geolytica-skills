# Geocoder.ca from the command line

## One-off lookups

```bash
# Forward geocode with standardized address and postal code
curl -sG 'https://geocoder.ca/' \
  --data-urlencode 'locate=330 metcalfe ottawa on' \
  --data geoit=XML --data json=1 --data standard=1 --data showpostal=1 \
  --data "auth=$GEOCODER_CA_AUTH" | jq .

# Postal code with boundary polygon
curl -sG 'https://geocoder.ca/' --data locate=K1A0A6 \
  --data geoit=XML --data json=1 --data getpolygon=1 --data "auth=$GEOCODER_CA_AUTH"

# Reverse geocode (allna=1 covers US points too)
curl -sG 'https://geocoder.ca/' \
  --data latt=45.4215 --data longt=-75.6972 --data reverse=1 --data allna=1 \
  --data geoit=XML --data json=1 --data "auth=$GEOCODER_CA_AUTH"

# Geoparse a block of text
curl -s 'https://geocoder.ca/' \
  --data-urlencode 'scantext=Meet at Bank and Somerset, then head to 330 Metcalfe St, Ottawa' \
  --data geoit=XML --data json=1 --data "auth=$GEOCODER_CA_AUTH" | jq '.match'
```

## Batch CSV (paid token)

For a few thousand rows with a token, a throttled loop is fine. For anything larger, or without a token, use https://geocoder.ca/batch or a licensed dataset instead.

```bash
#!/usr/bin/env bash
# usage: ./geocode.sh addresses.txt > out.csv   (one address per line)
set -euo pipefail
: "${GEOCODER_CA_AUTH:?set GEOCODER_CA_AUTH}"
echo 'input,lat,lon,postal,confidence,error'
while IFS= read -r line || [[ -n "$line" ]]; do
  [[ -z "$line" ]] && continue
  json=$(curl -sG 'https://geocoder.ca/' \
    --data-urlencode "locate=$line" \
    --data geoit=XML --data json=1 --data standard=1 --data showpostal=1 \
    --data "auth=$GEOCODER_CA_AUTH")
  code=$(jq -r '.error.code // ""' <<<"$json")
  if [[ "$code" == "002" || "$code" == "003" ]]; then
    echo "stopping: error $code (token out of credits or not found)" >&2; exit 1
  fi
  jq -r --arg in "$line" \
    '[$in, .latt // "", .longt // "", .postal // "", .standard.confidence // "", .error.code // ""] | @csv' \
    <<<"$json"
  sleep 0.2
done < "$1"
```

Stop the loop on error `002` (out of credits) or `003` (bad token) rather than writing thousands of failed rows. Every request costs a credit, including those that return an error, so drop empty or obviously invalid rows before the loop.
