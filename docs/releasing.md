# Releasing MWM

1. Make sure `master` has what you want to ship and the tests pass:

   ```bash
   script/check --release
   ```

   `script/check` runs the same tests as CI on this Mac (about 2 minutes), and `--release` also builds the
   universal app. Run it before opening any pull request that changes code. `script/install-hooks` installs
   a git pre-push hook that does it for you (docs-only pushes skip it; `SKIP_CHECK=1 git push` skips it once).
   CI on GitHub runs the same tests but waits for a macOS runner, which can take a long time; it ignores
   changes that only touch `docs/` or markdown files.

2. Build the release. This makes a universal app (Apple silicon and Intel), signs it with your
   "Apple Development" certificate, and writes `build/MWM-<version>.dmg`, `build/MWM-<version>.zip` and
   `build/SHA256SUMS.txt` (the version is `CFBundleShortVersionString`, so bump it first):

   ```bash
   script/build-dmg.sh
   ```

   The build uses its own install folder (`/tmp/MWMRelease.dst`), so it never replaces the
   development build the tests and `script/screens` use. The files in `build/` are not committed;
   the script also copies the three files to `docs/downloads/`, which is committed, and points the download links on the site pages (home, docs, features, examples) at the new file names.

3. Commit `docs/downloads/` in a pull request. Once merged, GitHub Pages serves the files, and the
   product page (`docs/index.html`) links to `docs/downloads/MWM-<version>.dmg` and `.zip` on `master` (`github.com/bbarbosa85/mwm/raw/master/docs/downloads/...`). Each release adds about 3.5 MB to the repository's history.

4. **Publish a GitHub release for the version** (not a draft), tagged `v` plus the app's version
   (`v1.0` for `CFBundleShortVersionString` 1.0). MWM's "Check for Updates" reads the repository's
   latest release and compares its tag with the running version, so without a newer release
   nobody is told there is an update. The release can have notes only; the downloads are served from
   the site:

   ```bash
   gh release create v1.0 --title "MWM 1.0" --notes "First MWM release."
   ```

5. Turn on GitHub Pages for the repository (Settings → Pages → Deploy from a branch → `master`,
   folder `/docs`). The page is then at `https://bbarbosa85.github.io/mwm/`.

## How the app updates itself

"Update now" in the update alert downloads `MWM-<version>.zip` and `SHA256SUMS.txt` from
`docs/downloads/` on `master` (`github.com/bbarbosa85/mwm/raw/master/docs/downloads/`), so a release
must have both there before its GitHub release is published. The app checks the zip against the
checksum, checks that it is MWM at that version, and that it was signed by the same certificate as the
running app (so Accessibility permission carries over). Then it quits, a small shell script swaps the
app in place and opens the new one; if the swap fails the old app is put back. When MWM is somewhere
the user can't write to, the alert opens the download page instead.

## Notes

- The app is signed but **not notarized**, so macOS asks people to confirm the first launch. The
  page explains how. Notarizing needs a paid Apple Developer membership and a "Developer ID
  Application" certificate; with one, add `xcrun notarytool submit` and `xcrun stapler staple` after
  signing in the script.
- Accessibility permission survives updates only while releases are signed with the same
  certificate (see `permissions-and-codesigning.md`).
- The version shown in About comes from `CFBundleShortVersionString` and `CFBundleVersion` in
  `MWM/App/MWM-Info.plist`.
