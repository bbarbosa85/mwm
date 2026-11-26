# Codebase Walkthrough & Internals

A guide to where things live. Sources are under `MWM/`, tests under `MWMTests/`, scripts under `script/`, the website and docs under `docs/`. MWM is Objective-C (AppKit), with no storyboards: windows and menus are built in code.

---

## 1. Source layout (`MWM/`)

### `App/`: the application
- [`main.m`](../MWM/App/main.m), [`MWMAppDelegate.{h,m}`](../MWM/App/MWMAppDelegate.m): entry point and app delegate. Owns the status item and its menu (built in code, in the order of the Settings sidebar), hotkey registration, Quartz event taps, modal input, login item, and the app menus.
- [`MWMUpdateChecker`](../MWM/App/MWMUpdateChecker.m), [`MWMUpdateInstaller`](../MWM/App/MWMUpdateInstaller.m): looks for a newer release on GitHub, and downloads, checks and installs it.

### `Config/`: what MWM loads and keeps
- [`MWMConfig`](../MWM/Config/MWMConfig.m): turns the active profile into bindings, layouts and settings that the operations use. [`Binding`](../MWM/Config/Binding.m), [`Layout`](../MWM/Config/Layout.m), [`ApplicationOptions`](../MWM/Config/ApplicationOptions.m) and [`Constants`](../MWM/Config/Constants.m) are the parts it builds from.
- **`Format/`**: the profile file. `MWMYAML` (the supported YAML subset), `MWMConfigFormat` (version 2 and the older layout), `MWMConfigDocument` (the editable model the Settings window works on), `MWMConfigValidator` (errors and warnings, never runs anything) and `MWMLegacyMigration` (`~/.mwm.yml`, `.slate`, `.slate.js`, `.slate.yml`).
- **`Shortcuts/`**: `MWMAction` (an action's kinds and fields, and its text), `MWMPushOptions`, `MWMShortcut`, `MWMShortcutIndex` (every shortcut with its group, kind and conflicts) and `MWMReservedShortcuts` (keys macOS keeps).
- **`Slots/`**: `MWMSlots` (presets and geometry), `MWMSlotShape` (a slot as fields) and `MWMFormula` (checking and evaluating a slot formula).
- [`MWMDisplays`](../MWM/Config/MWMDisplays.m): connected screens and screen "roles" (a name that survives docking).
- [`MWMProfiles`](../MWM/Config/MWMProfiles.m): the files in `~/.mwm`, the active one, and the `MWM_HOME` override used by development builds and tests.
- [`MWMSnapshots`](../MWM/Config/MWMSnapshots.m): saved window arrangements.
- [`MWMSync`](../MWM/Config/MWMSync.m), [`MWMSyncPlan`](../MWM/Config/MWMSyncPlan.m), [`MWMGist`](../MWM/Config/MWMGist.m): backup. `MWMSyncPlan` is the pure rule set (send, receive, flag a deletion), `MWMSync` runs it, `MWMGist` talks to GitHub (injectable transport, token in the Keychain).

### `Core/`: windows and screens
- [`AccessibilityWrapper`](../MWM/Core/AccessibilityWrapper.m) (Accessibility API), [`ScreenWrapper`](../MWM/Core/ScreenWrapper.m) (monitors and the two coordinate systems), [`RunningApplications`](../MWM/Core/RunningApplications.m) (live apps and windows), `WindowState`, `ScreenState`, and the snapshot model (`Snapshot`, `SnapshotList`, `WindowSnapshot`).

### `Operations/`: what a shortcut runs
One class per operation, on the base class [`Operation`](../MWM/Operations/Operation.m): `Move`, `Push`, `Resize`, `Nudge`, `Corner`, `Throw`, `Focus`, `Layout`, `Chain`, `Sequence`, `Grid`, `Hint`, `Switch`, `Snapshot`, `ActivateSnapshot`, `DeleteSnapshot`, `Undo`, `Shell`, `Visibility` and `Relaunch`. See the [Operations Reference](operations-reference.md).

### `Scripting/`
The JavaScript bridge from the Slate days (`JSController` and the `JS*Wrapper` classes). MWM no longer loads JavaScript configurations; see [Scripting](configuration-javascript.md).

### `UI/`
- **`App/`**: `MWMStatusMenus` (the Snapshots, Keyboard, Profiles and Backup submenus) and `MWMAboutWindow`.
- **`Components/`**: the design system. `MWMTheme` (colors, spacing, type, radii), `MWMComponents` (cards, list cards, name fields, option cards, save bar, chips, buttons), `MWMAlert`, `MWMSyncPresenter` and `MWMDesignGallery` (the "Design System…" window).
- **`Configuration/`**: the Settings window. `ConfigurationWindowController` (the window, the editing-versus-running profile, Apply), `ConfigurationFormView` (the sidebar and the pages), `ConfigurationStatusBar` and `ConfigurationProfileBar` (the bottom bar). Pages live in `Keyboard/` (map, list, modifiers, key caps), `Shortcuts/` (the shortcut editor, its push rows and action views), `Slots/` (gallery, editor, canvas, formula help) and `Pages/` (settings, displays, snapshots, backup, profiles). See [The Settings window](settings-window.md).
- **`Overlays/`**: the grid, window hints and application switcher windows. See [UI Components & Overlays](ui-and-overlays.md).

### `Utilities/`
`StringTokenizer`, `MathUtils`, `ExpressionPoint` (formulas via `NSExpression`), `ShellUtils`, `NSString+Levenshtein`, `NSString+Indicies`, `NSFileManager+ApplicationSupport`.

### `Resources/`
The app icon (`icon.icns`), the keyboard layout plists (`ASCIIToCode*.plist` for QWERTY, Dvorak, Colemak and AZERTY), and `default.slate`.

---

## 2. Tests (`MWMTests/`)

XCTest, run inside the app. `script/check` builds and runs everything the way CI does (about a minute); `script/check --release` also builds the universal Release app.

- **Logic**: formats, validation, migration, sync, slots, shortcuts, formulas, displays, snapshots, the gist client (against a fake GitHub in `TestFakeGitHub`), and the parsers and utilities.
- **Windows and pages**: the Settings window is tested through real views (profiles, bindings, slots, modifiers, autosave, the bottom bar and every page's width). Tests use temporary home folders (`MWMProfiles setHomeDirectory:`), never your files, and don't save the window's position.
- **Screenshots**: `TestSnapshots` draws the pages in light and dark and compares them with `MWMTests/Snapshots/*.png`. After a deliberate UI change, record the new images:

  ```bash
  TEST_RUNNER_MWM_RECORD_SNAPSHOTS=1 xcodebuild test -project MWM.xcodeproj -scheme MWM \
    -destination 'platform=macOS' -only-testing:MWMTests/TestSnapshots
  ```

  `script/screens` draws every page to PNGs and opens them in one page, to look at a change without relaunching the app.

---

## 3. Scripts and releases

- `script/check`: the tests (above). `script/install-hooks` installs a pre-push hook that runs it.
- `script/build-dmg.sh`: builds the universal app, signs it and writes `MWM-<version>.dmg` and `.zip`. See [Releasing](releasing.md).
- `script/build-examples-page`: regenerates `docs/examples.html` and the examples zip from `docs/examples/*.mwm.yml`.
- `script/generate-icons.swift`, `script/create-dmg`: the icon set and the disk image.
- Updates: **Check for Updates…** finds a newer GitHub release and installs it. See [Roadmap](roadmap.md) for notarization.
