#!/bin/sh
set -eu

: "${STASHSPHERE_API_HOST:=https://stash.example.com}"

cat > /usr/share/nginx/html/config.json <<EOF
{
  "apiHost": "${STASHSPHERE_API_HOST}"
}
EOF

echo "Generated frontend config.json with apiHost=${STASHSPHERE_API_HOST}" >&2
