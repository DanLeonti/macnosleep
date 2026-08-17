#!/bin/bash
set -euo pipefail

# Regenerates the landing page's images from the app itself: icons and the social card from the
# shared IconArtwork source, and the product shots from the running UI.
#
# The downloadable disk image is produced separately by ../release.sh, which also signs and
# notarises it.

cd "$(dirname "$0")/.."

echo "==> Rendering icons and social card"
swiftc -O Tools/GenerateSiteAssets.swift Sources/MacNoSleep/IconArtwork.swift \
  -o build/generate-site-assets
./build/generate-site-assets site/assets

echo "==> Capturing product screenshots"
swift build -c debug
./.build/debug/MacNoSleep --window site/assets/panel.png > /dev/null
./.build/debug/MacNoSleep --menubar docs/menubar-states.png > /dev/null

echo "==> Site assets ready"
