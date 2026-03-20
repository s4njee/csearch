#!/bin/sh
set -eu

RUNTIME_CONFIG_PATH="/usr/share/nginx/html/runtime-config.js"
API_SERVER="${NUXT_API_SERVER:-https://api.csearch.org}"

cat > "${RUNTIME_CONFIG_PATH}" <<EOF
window.__CSEARCH_RUNTIME_CONFIG__ = {
  API_SERVER: "${API_SERVER}"
};
EOF

exec nginx -g 'daemon off;'
