#!/bin/bash
set -euo pipefail

# Builds a Developer ID signed MacNoSleep, wraps it in a drag-to-install disk image, notarises
# that image with Apple, staples the ticket, and drops the result into the site's download folder.
#
# Requires a "Developer ID Application" certificate and a notarytool keychain profile. Create the
# profile once with:
#
#   xcrun notarytool store-credentials <profile-name> \
#     --apple-id <apple-id> --team-id <team-id> --password <app-specific-password>

cd "$(dirname "$0")"

APP_NAME="MacNoSleep"
BUILD_DIR="build"
APP_BUNDLE="${BUILD_DIR}/${APP_NAME}.app"
STAGE_DIR="${BUILD_DIR}/dmg"
NOTARY_PROFILE="${MACNOSLEEP_NOTARY_PROFILE:-text_polisher}"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' Resources/Info.plist)"
DMG_PATH="${BUILD_DIR}/${APP_NAME}-${VERSION}.dmg"

./build.sh

if codesign -dv "${APP_BUNDLE}" 2>&1 | grep -q "adhoc"; then
  echo "Refusing to release an ad-hoc signed build. Set MACNOSLEEP_SIGN_IDENTITY." >&2
  exit 1
fi

echo "==> Building disk image"
rm -rf "${STAGE_DIR}" "${DMG_PATH}"
mkdir -p "${STAGE_DIR}"
cp -R "${APP_BUNDLE}" "${STAGE_DIR}/"
ln -s /Applications "${STAGE_DIR}/Applications"

hdiutil create \
  -volname "${APP_NAME}" \
  -srcfolder "${STAGE_DIR}" \
  -fs HFS+ \
  -format UDZO \
  -ov \
  "${DMG_PATH}" > /dev/null

echo "==> Notarising (this usually takes a few minutes)"
xcrun notarytool submit "${DMG_PATH}" --keychain-profile "${NOTARY_PROFILE}" --wait

echo "==> Stapling"
xcrun stapler staple "${DMG_PATH}"
xcrun stapler validate "${DMG_PATH}"

echo "==> Verifying Gatekeeper acceptance"
spctl --assess --type execute --verbose=2 "${APP_BUNDLE}"

echo "==> Publishing into site/download"
mkdir -p site/download
rm -f site/download/*.dmg site/download/*.zip
cp "${DMG_PATH}" "site/download/${APP_NAME}-${VERSION}.dmg"
cp "${DMG_PATH}" "site/download/${APP_NAME}.dmg"

SIZE="$(awk -v bytes="$(stat -f%z "${DMG_PATH}")" 'BEGIN { printf "%.1f", bytes / 1048576 }')"

# The ampersand in "&nbsp;" has to be escaped or sed expands it to the whole match.
/usr/bin/sed -i '' \
  -e "s|<span id=\"version\">[^<]*</span>|<span id=\"version\">${VERSION}</span>|g" \
  -e "s|<span id=\"size\">[^<]*</span>|<span id=\"size\">${SIZE}\&nbsp;MB</span>|g" \
  site/index.html

echo "==> Released ${APP_NAME} ${VERSION} (${SIZE} MB)"
