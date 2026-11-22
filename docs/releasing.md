# Releasing MWM

1. Make sure `master` has what you want to ship and the tests pass:

   ```bash
   xcodebuild test -project Slate.xcodeproj -scheme Slate -destination 'platform=macOS'
   ```

2. Build the release. This makes a universal app (Apple silicon and Intel), signs it with your
   "Apple Development" certificate, and writes `build/MWM.dmg`, `build/MWM.zip` and
   `build/SHA256SUMS.txt`:

   ```bash
   script/build-dmg.sh
   ```

   The build uses its own install folder (`/tmp/MWMRelease.dst`), so it never replaces the
   development build the tests and `script/screens` use. The files in `build/` are not committed.

3. Publish the files as a GitHub release. The product page (`docs/index.html`) links to
   `releases/latest/download/MWM.dmg` and `MWM.zip`, so keep those two file names:

   ```bash
   gh release create v1.0 build/MWM.dmg build/MWM.zip build/SHA256SUMS.txt \
     --title "MWM 1.0" --notes "First MWM release."
   ```

4. Turn on GitHub Pages for the repository (Settings → Pages → Deploy from a branch → `master`,
   folder `/docs`). The page is then at `https://bbarbosa85.github.io/mwm/`.

## Notes

- The app is signed but **not notarized**, so macOS asks people to confirm the first launch. The
  page explains how. Notarizing needs a paid Apple Developer membership and a "Developer ID
  Application" certificate; with one, add `xcrun notarytool submit` and `xcrun stapler staple` after
  signing in the script.
- Accessibility permission survives updates only while releases are signed with the same
  certificate (see `permissions-and-codesigning.md`).
- The version shown in About comes from `CFBundleShortVersionString` and `CFBundleVersion` in
  `Slate/App/Slate-Info.plist`.
