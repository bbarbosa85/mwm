#!/usr/bin/env bash
set -euo pipefail

# Script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

CONFIGURATION="${1:-Release}"
DMG_NAME="MWM.dmg"
OUTPUT_DIR="${ROOT_DIR}/build"
STAGING_DIR="/tmp/mwm_dmg_staging_$$"

echo "==> Building MWM (${CONFIGURATION})..."
cd "${ROOT_DIR}"
xcodebuild -scheme Slate \
           -configuration "${CONFIGURATION}" \
           -derivedDataPath /tmp/MWMDerivedData \
           build

APP_PATH="${ROOT_DIR}/tmp/Slate.dst/Applications/MWM.app"
if [ ! -d "${APP_PATH}" ]; then
  APP_PATH="/tmp/MWMDerivedData/Build/Products/${CONFIGURATION}/MWM.app"
fi

if [ ! -d "${APP_PATH}" ]; then
  echo "Error: MWM.app not found at ${APP_PATH}" >&2
  exit 1
fi

# Signing identity: can be overridden via SIGN_IDENTITY env var or auto-detected
SIGN_IDENTITY="${SIGN_IDENTITY:-}"
if [ -z "${SIGN_IDENTITY}" ]; then
  if security find-identity -v -p codesigning 2>/dev/null | grep -q "Apple Development"; then
    SIGN_IDENTITY="Apple Development"
  else
    SIGN_IDENTITY="-"
  fi
fi

echo "==> Preparing DMG staging directory..."
rm -rf "${STAGING_DIR}"
mkdir -p "${STAGING_DIR}"
cp -R "${APP_PATH}" "${STAGING_DIR}/MWM.app"
echo "==> Signing MWM.app bundle with signature: ${SIGN_IDENTITY}..."
codesign --force --deep --sign "${SIGN_IDENTITY}" "${STAGING_DIR}/MWM.app"
ln -s /Applications "${STAGING_DIR}/Applications"

mkdir -p "${OUTPUT_DIR}"
DMG_PATH="${OUTPUT_DIR}/${DMG_NAME}"
rm -f "${DMG_PATH}"

echo "==> Creating DMG: ${DMG_PATH}..."
hdiutil create -volname "MWM" \
               -srcfolder "${STAGING_DIR}" \
               -ov \
               -format UDZO \
               "${DMG_PATH}"

rm -rf "${STAGING_DIR}"

echo "==> Successfully created DMG:"
ls -lh "${DMG_PATH}"

