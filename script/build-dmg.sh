#!/usr/bin/env bash
set -euo pipefail

# Script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

CONFIGURATION="${1:-Release}"
# Files carry the version: MWM-1.0.dmg, from CFBundleShortVersionString in MWM-Info.plist.
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$(dirname "$0")/../MWM/App/MWM-Info.plist")"
DMG_NAME="MWM-${VERSION}.dmg"
OUTPUT_DIR="${ROOT_DIR}/build"
STAGING_DIR="/tmp/mwm_dmg_staging_$$"

echo "==> Building MWM (${CONFIGURATION})..."
cd "${ROOT_DIR}"
# A universal app (Apple silicon and Intel), installed into its own folder so it never replaces the
# development build that the tests and "script/screens" use (tmp/MWM.dst).
RELEASE_DST="/tmp/MWMRelease.dst"
rm -rf "${RELEASE_DST}"
xcodebuild -scheme MWM \
           -configuration "${CONFIGURATION}" \
           -destination 'generic/platform=macOS' \
           -derivedDataPath /tmp/MWMDerivedData \
           DSTROOT="${RELEASE_DST}" \
           ONLY_ACTIVE_ARCH=NO \
           build

APP_PATH="${RELEASE_DST}/Applications/MWM.app"
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

# The same signed app as a zip, and checksums for both.
ZIP_PATH="${OUTPUT_DIR}/MWM-${VERSION}.zip"
rm -f "${ZIP_PATH}"
ditto -c -k --sequesterRsrc --keepParent "${STAGING_DIR}/MWM.app" "${ZIP_PATH}"
(cd "${OUTPUT_DIR}" && shasum -a 256 "${DMG_NAME}" "$(basename "${ZIP_PATH}")" > SHA256SUMS.txt)

# The product page serves the files from docs/downloads (GitHub Pages), so they are copied there.
DOWNLOADS="$(dirname "$0")/../docs/downloads"
mkdir -p "${DOWNLOADS}"
cp "${DMG_PATH}" "${ZIP_PATH}" "${DOWNLOADS}/"
cp "${OUTPUT_DIR}/SHA256SUMS.txt" "${DOWNLOADS}/SHA256SUMS.txt"
# ...and the page's download links are pointed at them.
for page in index.html docs.html features.html examples.html changelog.html; do
  sed -i '' -E "s#downloads/MWM[-0-9.]*\.(dmg|zip)#downloads/MWM-${VERSION}.\1#g" "$(dirname "$0")/../docs/${page}"
done
# ...and so is the version the home page names under the Download button.
sed -i '' -E "s#Version [0-9][0-9.]* ·#Version ${VERSION} ·#" "$(dirname "$0")/../docs/index.html"

rm -rf "${STAGING_DIR}"

echo "==> Successfully created the release:"
ls -lh "${DMG_PATH}" "${ZIP_PATH}"
cat "${OUTPUT_DIR}/SHA256SUMS.txt"

