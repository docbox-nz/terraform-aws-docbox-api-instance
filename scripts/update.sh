#!/bin/bash
# ===
# This script handles updating docbox
# ===

# Variables injected into the template
PROXY_URL="${proxy_url}"
BINARY_URL="${binary_url}"

TMP_SERVER_PATH="/tmp/docbox"
SERVER_PATH="/docbox/app"
SERVER_PATH_ALT="/docbox/app-previous"

# Set HTTPS proxy before downloading update only if PROXY_URL is not empty
if [ -n "$PROXY_URL" ]; then
    export HTTPS_PROXY="$PROXY_URL"
fi

# Download office converter server binary
curl -L -o $TMP_SERVER_PATH $BINARY_URL

# Move current docbox server binary
sudo mv $SERVER_PATH $SERVER_PATH_ALT

# Move the new docbox server binary
sudo mv $TMP_SERVER_PATH $SERVER_PATH

# Ensure the binary has execute permissions
sudo chmod +x $SERVER_PATH

# Restart the service
sudo systemctl restart docbox.service
