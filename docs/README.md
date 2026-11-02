# Slate Documentation

Welcome to the internal and technical documentation for **Slate**, a highly customizable, programmable window management application for macOS (OS X 10.6+) written in Objective-C with JavaScript scripting support.

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

3. **[JavaScript Scripting Engine (`.slate.js`)](configuration-javascript.md)**
   - WebKit JavaScript runtime integration (`JSController`, WebScript bridge).
   - The global `slate` (`S`) object and API methods.
   - Object wrappers: `JSWindowWrapper`, `JSApplicationWrapper`, `JSScreenWrapper`, `JSInfoWrapper`.
   - Event-driven automation: system event triggers (`appOpened`, `windowMoved`, `screenConfigurationChanged`, etc.).
   - Underscore.js embedded utilities and test harnesses (`slate-mock.js`).

4. **[Operations Reference](operations-reference.md)**
   - Comprehensive reference of all built-in window and system operations:
     - Window positioning & sizing: `move`, `resize`, `push`, `nudge`, `throw`, `corner`.
     - Layout & orchestration: `chain`, `sequence`, `layout`.
     - Window navigation & focus: `focus`, `hint`, `switch`.
     - State persistence: `snapshot`, `activate-snapshot`, `delete-snapshot`, `undo`.
     - System & automation: `shell`, `hide`, `show`, `toggle`, `relaunch`.

5. **[UI Components & Overlays](ui-and-overlays.md)**
   - Interactive screen grid overlay (`GridWindow`, `GridView`, `GridCellView`).
   - Vimium-style visual window hints (`HintWindow`, `HintView`, collision spread algorithm).
   - Custom application switcher (`SwitchWindow`, `SwitchView`, `SwitchAppView`, quick actions `q`/`f`/`h`/`` ` ``).
   - Window inspector & configuration helper panels (`WindowInfoView`, `ConfigurationHelperView`).

6. **[Codebase Walkthrough & Internals](codebase-walkthrough.md)**
   - Directory structure and file manifest.
   - String tokenization (`StringTokenizer`), Levenshtein distance (`NSString+Levenshtein`), math utilities (`MathUtils`).
   - Keyboard layout plists (QWERTY, Dvorak, Colemak, AZERTY).
   - Unit test suite (`SlateTests`).
   - Build system, release pipeline (`slate.rb`), DMG staging, and Sparkle framework updater.

---

## Quick Repository Overview

| Directory / File | Description |
| :--- | :--- |
| `Slate/` | Main Objective-C source files, UI views, operation classes, JS bridge, and assets. |
| `Slate/JSONKit/` | Embedded high-performance JSONKit library for snapshot serialization. |
| `SlateTests/` | Unit tests for tokenizer, math parser, expressions, Levenshtein, and string helpers. |
| `script/` | Release automation (`slate.rb`) and disk image packager (`create-dmg`). |
| `Sparkle.framework` | Integrated auto-update framework for macOS. |
| `Slate.xcodeproj` | Xcode project defining `Slate`, `SlateTests`, and Release/Debug build targets. |
| `README.md` | User-facing usage instructions and quick configuration guide. |
| `VERSION` | Current release number (1.0.25) and detailed release notes. |

