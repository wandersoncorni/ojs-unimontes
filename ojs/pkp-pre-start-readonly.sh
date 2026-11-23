#!/bin/sh
set -eu

KEY_PATH="/etc/ssl/apache2/server.key"
PEM_PATH="/etc/ssl/apache2/server.pem"
CHAIN_PATH="/etc/ssl/apache2/chain.pem"

sed -i -e "s/restful_urls = Off/restful_urls = On/g" "$PKP_CONF"
sed -i -e "s/enable_cdn = On/enable_cdn = Off/g" "$PKP_CONF"

if [ ! -f "$KEY_PATH" ] ||
   ! openssl x509 -in "$PEM_PATH" -noout -subject | grep -q "$SERVERNAME"; then
    openssl req -x509 -nodes -days 1460 -newkey rsa:2048 \
        -keyout "$KEY_PATH" -out "$PEM_PATH" -subj "/CN=$SERVERNAME/"
fi

if [ ! -f "$CHAIN_PATH" ]; then
    cat "$PEM_PATH" > "$CHAIN_PATH"
fi

if [ "${PKP_CLI_INSTALL:-0}" = "1" ] &&
    grep -q 'installed = Off' "$PKP_CONF"; then
    /usr/local/bin/pkp-cli-install
fi
