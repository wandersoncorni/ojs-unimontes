#!/bin/sh
set -eu

cp /run/secrets/ojs_config "$PKP_CONF"
chmod 0600 "$PKP_CONF"

exec /usr/local/bin/pkp-start
