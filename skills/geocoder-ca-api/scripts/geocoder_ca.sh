#!/usr/bin/env bash
# Call the Geocoder.ca API with the token read from the environment.
#
# usage: geocoder_ca.sh name=value [name=value ...]
#   geocoder_ca.sh 'locate=350 5th Ave, New York, NY' standard=1 showpostal=1
#   geocoder_ca.sh latt=45.4215 longt=-75.6972 reverse=1 allna=1
#   geocoder_ca.sh 'scantext=Meet at 330 Metcalfe St, Ottawa'
#
# Each argument is sent URL-encoded. geoit=XML and json=1 are added unless you
# pass your own geoit= or json=. If GEOCODER_CA_AUTH is set it is sent as auth=;
# otherwise the request goes to the free, throttled port. The token is never
# printed. scantext requests are sent as POST, everything else as GET.
set -euo pipefail

if [[ $# -eq 0 ]]; then
  sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//' >&2
  exit 2
fi

args=() method=(-G) has_geoit=0 has_json=0
for kv in "$@"; do
  if [[ "$kv" != *=* ]]; then
    echo "geocoder_ca.sh: expected name=value, got: $kv" >&2; exit 2
  fi
  case "$kv" in
    auth=*) echo "geocoder_ca.sh: don't pass auth=; set GEOCODER_CA_AUTH instead" >&2; exit 2 ;;
    geoit=*) has_geoit=1 ;;
    json=*) has_json=1 ;;
    scantext=*) method=() ;;
  esac
  args+=(--data-urlencode "$kv")
done
[[ $has_geoit -eq 1 ]] || args+=(--data geoit=XML)
[[ $has_json  -eq 1 ]] || args+=(--data json=1)
if [[ -n "${GEOCODER_CA_AUTH:-}" ]]; then
  args+=(--data-urlencode "auth=${GEOCODER_CA_AUTH}")
else
  echo "geocoder_ca.sh: GEOCODER_CA_AUTH not set; using the free throttled port" >&2
fi

exec curl -sS --max-time 60 "${method[@]}" 'https://geocoder.ca/' "${args[@]}"
