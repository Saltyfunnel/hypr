#!/bin/bash

STEAM_DIR="$HOME/.steam/root/compatibilitytools.d"
mkdir -p "$STEAM_DIR"

echo "Fetching the latest GE-Proton release URL..."

# Use python to cleanly parse the JSON release URL without regex brittleness
LATEST_URL=$(curl -s https://api.github.com/repos/GloriousEggroll/proton-ge-custom/releases/latest | python3 -c "
import sys, json
data = json.load(sys.stdin)
for asset in data.get('assets', []):
    if asset['name'].endswith('.tar.gz'):
        print(asset['browser_download_url'])
        break
")

if [ -z "$LATEST_URL" ]; then
    echo "Error: Failed to fetch the latest release URL."
    exit 1
fi

TARBALL=$(basename "$LATEST_URL")

echo "Downloading $TARBALL..."
curl -L -o "/tmp/$TARBALL" "$LATEST_URL"

if [ ! -f "/tmp/$TARBALL" ]; then
    echo "Error: Download failed."
    exit 1
fi

echo "Extracting into $STEAM_DIR..."
tar -xzf "/tmp/$TARBALL" -C "$STEAM_DIR"

# Cleanup
rm -f "/tmp/$TARBALL"

echo "Done! Restart Steam and select your new GE-Proton version under Steam Play settings."
