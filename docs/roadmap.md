# Roadmap

What is planned but not built yet. Move an item out when it ships.

## Check for Updates

A new menu bar item, grouped with About MWM:

```
Launch MWM at Login
────────────
About MWM
Check for Updates…
────────────
Quit MWM
```

- Asks GitHub's latest release whether a newer version than the running one exists, and says so in an MWM alert with a "Download" button (opens the release page) or "You're up to date".
- Open questions: automatic checks (daily, off by default?) versus manual only; Sparkle (needs a signed appcast and notarization) versus a plain check of the releases API.
- Depends on releases being published on GitHub with a version tag (see [releasing.md](releasing.md)).

## Backup page

Not built: there is no GitHub or gist code in the app yet. The placeholder Backup page and menu item were removed, and come back with the feature. Plan: back up `~/.mwm.yml` to a private gist, and restore from it, from a Backup page in the window (Settings group) and an item in the menu bar menu.

- Open question: how MWM signs in to GitHub. A personal access token pasted into the page (gist scope, kept in the Keychain) is simplest; GitHub's device login flow is nicer but needs a registered OAuth app.
- Decide what is backed up: `~/.mwm.yml` only, or also kept snapshots.

## Notarization

Releases are signed but not notarized, so macOS warns on first open. Needs a paid Apple developer membership; also a prerequisite for in-app updates through Sparkle.

## Smaller items

- A read-only list of the shortcuts macOS keeps, under Advanced.
- Animations for moving windows.
