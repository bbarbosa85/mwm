# Roadmap

What is planned but not built yet. Move an item out when it ships.

## Backup page

Not built: there is no GitHub or gist code in the app yet. The placeholder Backup page and menu item were removed, and come back with the feature. Plan: back up `~/.mwm.yml` to a private gist, and restore from it, from a Backup page in the window (Settings group) and an item in the menu bar menu.

- Open question: how MWM signs in to GitHub. A personal access token pasted into the page (gist scope, kept in the Keychain) is simplest; GitHub's device login flow is nicer but needs a registered OAuth app.
- Decide what is backed up: `~/.mwm.yml` only, or also kept snapshots.

## Notarization

Releases are signed but not notarized, so macOS warns on first open. Needs a paid Apple developer membership; also a prerequisite for in-app updates (Sparkle). Until then, "Check for Updates" only tells you a new version exists and opens the download page.

## Smaller items

- A read-only list of the shortcuts macOS keeps, under Advanced.
- Animations for moving windows.
