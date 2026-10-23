#!/usr/bin/env bash
# Call the Geocode.xyz API with the key read from the environment.
#
# usage: geocode_xyz.sh name=value [name=value ...]
#   geocode_xyz.sh 'locate=10 Downing St, London' region=UK
#   geocode_xyz.sh 'locate=51.5034,-0.1276' moreinfo=1
#   geocode_xyz.sh 'scantext=The museums of Amsterdam are on the Museumplein.' region=NL
#
# Each argument is sent URL-encoded. json=1 is added unless you pass another
# output format (json=, geojson=, geoit=). If GEOCODE_XYZ_AUTH is set it is
# sent as auth=; otherwise the request goes to the shared free, throttled port.
# The key is never printed. scantext requests are sent as POST, others as GET.
set -euo pipefail

if [[ $# -eq 0 ]]; then
  sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//' >&2
  exit 2
fi

args=() method=(-G) has_format=0
for kv in "$@"; do
  if [[ "$kv" != *=* ]]; then
    echo "geocode_xyz.sh: expected name=value, got: $kv" >&2; exit 2
  fi
  case "$kv" in
    auth=*) echo "geocode_xyz.sh: don't pass auth=; set GEOCODE_XYZ_AUTH instead" >&2; exit 2 ;;
    json=*|geojson=*|geoit=*) has_format=1 ;;
    scantext=*) method=() ;;
  esac
  args+=(--data-urlencode "$kv")
done
[[ $has_format -eq 1 ]] || args+=(--data json=1)
if [[ -n "${GEOCODE_XYZ_AUTH:-}" ]]; then
  args+=(--data-urlencode "auth=${GEOCODE_XYZ_AUTH}")
else
  echo "geocode_xyz.sh: GEOCODE_XYZ_AUTH not set; using the shared free throttled port" >&2
fi

exec curl -sS --max-time 60 ${method[@]+"${method[@]}"} 'https://geocode.xyz/' "${args[@]}"
