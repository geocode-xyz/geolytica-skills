# Geocode.xyz from the command line

## One-off lookups

```bash
# Forward geocode, biased to a country
curl -sG 'https://geocode.xyz/' \
  --data-urlencode 'locate=34 Threadneedle Street, London' \
  --data region=UK --data json=1 --data "auth=$GEOCODE_XYZ_AUTH" | jq .

# Reverse geocode (latitude first), address only
curl -sG 'https://geocode.xyz/' \
  --data 'locate=51.50354,-0.12768' --data strictmode=1 \
  --data json=1 --data "auth=$GEOCODE_XYZ_AUTH"

# Reverse with timezone and elevation
curl -sG 'https://geocode.xyz/' \
  --data 'locate=40.47552,19.49845' --data moreinfo=1 \
  --data json=1 --data "auth=$GEOCODE_XYZ_AUTH"

# Geoparse text into GeoJSON
curl -s https://geocode.xyz/ \
  --data-urlencode 'scantext=The Vienna Tourist Board operates booths at the airport and at Albertinaplatz.' \
  --data region=AT --data geojson=1 --data "auth=$GEOCODE_XYZ_AUTH"

# Postcode autocomplete
curl -sG 'https://geocode.xyz/' \
  --data region=DE --data streetname=0113 --data geoit=json | jq '.standard.street'
```

## Batch CSV (with a key)

```bash
#!/usr/bin/env bash
# usage: ./geocode-xyz.sh places.txt UK > out.csv   (one location per line; region optional)
set -euo pipefail
: "${GEOCODE_XYZ_AUTH:?set GEOCODE_XYZ_AUTH}"
region="${2:-}"
echo 'input,lat,lon,country,confidence,error'
while IFS= read -r line || [[ -n "$line" ]]; do
  [[ -z "$line" ]] && continue
  json=$(curl -s https://geocode.xyz/ \
    --data-urlencode "locate=$line" ${region:+--data "region=$region"} \
    --data json=1 --data "auth=$GEOCODE_XYZ_AUTH")
  code=$(jq -r '.error.code // ""' <<<"$json")
  if [[ "$code" == "002" || "$code" == "003" ]]; then
    echo "stopping: error $code" >&2; exit 1
  fi
  jq -r --arg in "$line" '
    def s: if type=="object" then (if length==0 then "" else . end) else . // "" end;
    [$in, (.latt|s), (.longt|s), ((.standard.prov // .prov)|s),
     ((.standard.confidence // .confidence)|s), (.error.code // "")] | @csv' <<<"$json"
  sleep 0.15
done < "$1"
```

For files of more than a few thousand lines, use https://geocode.xyz/batch instead.
