# MWM Documentation

Documentation for **MWM** (Mac Window Manager), a fork of [Slate](https://github.com/jigish/slate): a keyboard-driven window manager for macOS 12 and later, written in Objective-C. For how to use it, start with the [website docs](https://bbarbosa85.github.io/mwm/docs.html); these files are the reference and the internals.

---

## Documentation Index

1. **[System Architecture](architecture.md)**
   - High-level design and design philosophy.
   - macOS Accessibility API (`AXUIElementRef`, `AXObserverRef`) integration.
   - Dual coordinate systems (Cocoa bottom-left vs. Accessibility top-left).
   - Event Tap interceptors (Quartz event taps for `Cmd+Tab`).
   - Carbon HotKey registration and repeat timers.
   - Multi-monitor management and dynamic display reconfiguration.

2. **[Classic Configuration (`.slate`)](configuration-slate.md)**
   - Directives: `config`, `alias`, `layout`, `default`, `bind`, `source`.
   - Mathematical expression engine (`NSExpression` evaluator and variables).
   - Key syntax, modifiers, and modal keybinding states.
   - Application-specific configurations.
   - Complete global configuration options table with default values.

3. **[Profiles (`~/.mwm`)](configuration-yaml.md)**
   - The YAML format MWM loads, and the supported YAML subset.
   - Several profiles in `~/.mwm`, switching between them, and syncing them with a private gist.
   - Migration from `.slate` and `.slate.js`.

   **[The Settings window](settings-window.md)**
   - The sidebar (Keyboard, Screens, Options, Other), the bottom bar and applying a profile.
   - Bindings: the keyboard map, the list, and the shortcut page with its action cards.
   - Slots: the drag editor, grid, position, size and margins, and formulas.
   - Displays, Options, Snapshots, Backup, Profiles, and the design system.

4. **[JavaScript Scripting Engine (`.slate.js`, no longer loaded)](configuration-javascript.md)**
   - WebKit JavaScript runtime integration (`JSController`, WebScript bridge).
   - The global `slate` (`S`) object and API methods.
   - Object wrappers: `JSWindowWrapper`, `JSApplicationWrapper`, `JSScreenWrapper`, `JSInfoWrapper`.
   - Event-driven automation: system event triggers (`appOpened`, `windowMoved`, `screenConfigurationChanged`, etc.).
   - Underscore.js embedded utilities and test harnesses (`slate-mock.js`).

5. **[Operations Reference](operations-reference.md)**
   - Comprehensive reference of all built-in window and system operations:
     - Window positioning & sizing: `move`, `resize`, `push`, `nudge`, `throw`, `corner`.
     - Layout & orchestration: `chain`, `sequence`, `layout`.
     - Window navigation & focus: `focus`, `hint`, `switch`.
     - State persistence: `snapshot`, `activate-snapshot`, `delete-snapshot`, `undo`.
     - System & automation: `shell`, `hide`, `show`, `toggle`, `relaunch`.

6. **[UI Components & Overlays](ui-and-overlays.md)**
   - Interactive screen grid overlay (`GridWindow`, `GridView`, `GridCellView`).
   - Vimium-style visual window hints (`HintWindow`, `HintView`, collision spread algorithm).
   - Custom application switcher (`SwitchWindow`, `SwitchView`, `SwitchAppView`, quick actions `q`/`f`/`h`/`` ` ``).

7. **[Codebase Walkthrough & Internals](codebase-walkthrough.md)**
   - Directory structure and file manifest.
   - String tokenization (`StringTokenizer`), Levenshtein distance (`NSString+Levenshtein`), math utilities (`MathUtils`).
   - Keyboard layout plists (QWERTY, Dvorak, Colemak, AZERTY).
   - Unit test suite (`MWMTests`).
   - Build system, release pipeline (`script/build-dmg.sh`), and DMG staging.

8. **[macOS Permissions & Code Signing Guide](permissions-and-codesigning.md)**
   - macOS TCC (Transparency, Consent, and Control) security model for accessibility.
   - Why permissions are invalidated when updating or rebuilding ad-hoc binaries.
   - How to create a persistent self-signed code signing certificate in Keychain Access.
   - How to configure persistent signing in Xcode and `script/build-dmg.sh` to preserve permissions across all updates.
   - Troubleshooting and resetting stale permission entries with `tccutil`.

---

## Quick Repository Overview

| Directory / File | Description |
| :--- | :--- |
| `MWM/` | The app: `App`, `Config`, `Core`, `Operations`, `Scripting`, `UI` and `Utilities` (see the walkthrough). |
| `MWMTests/` | XCTest unit, window and screenshot tests; `script/check` runs them all. |
| `script/build-dmg.sh` | Modern native packaging script to build Release DMG disk images. |
| `script/` | Build scripts and release automation helpers. |
| `MWM.xcodeproj` | Xcode project defining `MWM`, `MWMTests`, and Release/Debug build targets. |
| `docs/` | These guides, and the website (`index.html`, `docs.html`, `features.html`, `examples.html`). |
| `README.md` | User-facing usage instructions and quick configuration guide. |
| `VERSION` | Current release number (1.0.25) and detailed release notes. |

