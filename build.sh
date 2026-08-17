#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")"

APP_NAME="MacNoSleep"
BUILD_DIR="build"
APP_BUNDLE="${BUILD_DIR}/${APP_NAME}.app"
CONFIGURATION="release"

# Prefer a Developer ID certificate so the result can be notarised; fall back to an ad-hoc
# signature so the project still builds on a machine without one.
if [[ -n "${MACNOSLEEP_SIGN_IDENTITY:-}" ]]; then
  SIGN_IDENTITY="${MACNOSLEEP_SIGN_IDENTITY}"
else
  SIGN_IDENTITY="$(
    security find-identity -v -p codesigning \
      | awk -F'"' '/Developer ID Application/ { print $2; exit }'
  )"
  SIGN_IDENTITY="${SIGN_IDENTITY:--}"
fi

UNIVERSAL=1
if [[ "${1:-}" == "--native" ]]; then
  UNIVERSAL=0
fi

echo "==> Building ${APP_NAME} (${CONFIGURATION})"
if [[ ${UNIVERSAL} -eq 1 ]]; then
  swift build -c "${CONFIGURATION}" --arch arm64 --arch x86_64
  BINARY=".build/apple/Products/Release/${APP_NAME}"
else
  swift build -c "${CONFIGURATION}"
  BINARY="$(swift build -c "${CONFIGURATION}" --show-bin-path)/${APP_NAME}"
fi

echo "==> Rendering app icon"
ICONSET="${BUILD_DIR}/AppIcon.iconset"
rm -rf "${ICONSET}"
mkdir -p "${ICONSET}"
swiftc -O Tools/GenerateIcon.swift Sources/MacNoSleep/IconArtwork.swift -o "${BUILD_DIR}/generate-icon"
"${BUILD_DIR}/generate-icon" "${ICONSET}"
iconutil -c icns "${ICONSET}" -o "${BUILD_DIR}/AppIcon.icns"

echo "==> Assembling ${APP_BUNDLE}"
rm -rf "${APP_BUNDLE}"
mkdir -p "${APP_BUNDLE}/Contents/MacOS" "${APP_BUNDLE}/Contents/Resources"

cp "${BINARY}" "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"
cp Resources/Info.plist "${APP_BUNDLE}/Contents/Info.plist"
cp "${BUILD_DIR}/AppIcon.icns" "${APP_BUNDLE}/Contents/Resources/AppIcon.icns"
printf 'APPL????' > "${APP_BUNDLE}/Contents/PkgInfo"

echo "==> Signing with identity: ${SIGN_IDENTITY}"
if [[ "${SIGN_IDENTITY}" == "-" ]]; then
  echo "    (ad-hoc: the result cannot be notarised)"
  codesign --force --sign - "${APP_BUNDLE}"
else
  codesign --force --options runtime --timestamp --sign "${SIGN_IDENTITY}" "${APP_BUNDLE}"
fi

codesign --verify --strict --verbose=1 "${APP_BUNDLE}"

echo "==> Done: ${APP_BUNDLE}"
