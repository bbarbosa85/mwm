# Codebase Walkthrough & Internals

This document provides a component-by-component, file-by-file guide to the Slate codebase.

---

## 1. File & Component Manifest

### Core Application
- **[`Slate/main.m`](file:///Users/brunobarbosa/Projetos/mwm/mwm/Slate/main.m)**: Process entry point; invokes `NSApplicationMain`.
- **[`Slate/SlateAppDelegate.{h,m}`](file:///Users/brunobarbosa/Projetos/mwm/mwm/Slate/SlateAppDelegate.m)**: App delegate; coordinates status bar item, hotkey registration, Quartz event taps, modal input handling, login items, and the status and app menus (built in code).
- **[`Slate/SlateConfig.{h,m}`](file:///Users/brunobarbosa/Projetos/mwm/mwm/Slate/SlateConfig.m)**: Configuration engine; parses `.slate` directives, aliases, and layouts; manages snapshot persistence.
- **[`Slate/Constants.{h,m}`](file:///Users/brunobarbosa/Projetos/mwm/mwm/Slate/Constants.m)**: Central definitions of all string constants, config keys, default values, and token identifiers.
- **[`Slate/SlateLogger.h`](file:///Users/brunobarbosa/Projetos/mwm/mwm/Slate/SlateLogger.h)**: Logging macro abstractions (`SlateLogger`).
- **[`Slate/NSFileManager+ApplicationSupport.{h,m}`](file:///Users/brunobarbosa/Projetos/mwm/mwm/Slate/NSFileManager+ApplicationSupport.m)**: Category to resolve and ensure `~/Library/Application Support/Slate`.

### Window & Screen Abstraction
- **[`Slate/AccessibilityWrapper.{h,m}`](file:///Users/brunobarbosa/Projetos/mwm/mwm/Slate/AccessibilityWrapper.m)**: Core wrapper around macOS Accessibility APIs (`AXUIElementRef`, `AXObserverRef`). Reads and writes window positions and sizes, inspects roles, brings windows to front, and conducts hit-testing.
- **[`Slate/ScreenWrapper.{h,m}`](file:///Users/brunobarbosa/Projetos/mwm/mwm/Slate/ScreenWrapper.m)**: Manages multi-monitor geometries, coordinate system flipping (Cocoa bottom-left to AX top-left), and monitor resolution/direction matching.
- **[`Slate/RunningApplications.{h,m}`](file:///Users/brunobarbosa/Projetos/mwm/mwm/Slate/RunningApplications.m)**: Live registry of active applications and their open windows via `NSWorkspace` notifications and `AXObserver` callbacks.
- **[`Slate/WindowState.{h,m}`](file:///Users/brunobarbosa/Projetos/mwm/mwm/Slate/WindowState.m)**: Value object encapsulating snapshot state (PID, position, size) of a window.
- **[`Slate/ScreenState.{h,m}`](file:///Users/brunobarbosa/Projetos/mwm/mwm/Slate/ScreenState.m)**: Encapsulates monitor layout rules and resolution match conditions.

### Operation Hierarchy
- **[`Slate/Operation.{h,m}`](file:///Users/brunobarbosa/Projetos/mwm/mwm/Slate/Operation.m)**: Abstract base class providing lifecycle hooks (`initOptions:`, `evalOptions:`, `doOperation`, `testOperation`).
- **[`Slate/MoveOperation.{h,m}`](file:///Users/brunobarbosa/Projetos/mwm/mwm/Slate/MoveOperation.m)**: Core position & size mutator.
- **[`Slate/PushOperation.{h,m}`](file:///Users/brunobarbosa/Projetos/mwm/mwm/Slate/PushOperation.m)**: Edge push with optional bar and center styles.
- **[`Slate/ResizeOperation.{h,m}`](file:///Users/brunobarbosa/Projetos/mwm/mwm/Slate/ResizeOperation.m)**: Relative resizing with corner anchoring.
- **[`Slate/NudgeOperation.{h,m}`](file:///Users/brunobarbosa/Projetos/mwm/mwm/Slate/NudgeOperation.m)**: Offset translation.
- **[`Slate/CornerOperation.{h,m}`](file:///Users/brunobarbosa/Projetos/mwm/mwm/Slate/CornerOperation.m)**: Snap-to-corner positioning.
- **[`Slate/ThrowOperation.{h,m}`](file:///Users/brunobarbosa/Projetos/mwm/mwm/Slate/ThrowOperation.m)**: Monitor-to-monitor window movement.
- **[`Slate/FocusOperation.{h,m}`](file:///Users/brunobarbosa/Projetos/mwm/mwm/Slate/FocusOperation.m)**: Geometric directional focus (`left`, `right`, `above`, `below`, `behind`).
- **[`Slate/LayoutOperation.{h,m}`](file:///Users/brunobarbosa/Projetos/mwm/mwm/Slate/LayoutOperation.m)** & **[`Slate/Layout.{h,m}`](file:///Users/brunobarbosa/Projetos/mwm/mwm/Slate/Layout.m)**: Multi-app layout engine with regex title matching and window sequencing.
- **[`Slate/ChainOperation.{h,m}`](file:///Users/brunobarbosa/Projetos/mwm/mwm/Slate/ChainOperation.m)**: Successive operation cycling.
- **[`Slate/SequenceOperation.{h,m}`](file:///Users/brunobarbosa/Projetos/mwm/mwm/Slate/SequenceOperation.m)**: Compound multi-operation execution.
- **[`Slate/GridOperation.{h,m}`](file:///Users/brunobarbosa/Projetos/mwm/mwm/Slate/GridOperation.m)**: Interactive grid invoker.
- **[`Slate/HintOperation.{h,m}`](file:///Users/brunobarbosa/Projetos/mwm/mwm/Slate/HintOperation.m)**: Window hint overlay controller.
- **[`Slate/SwitchOperation.{h,m}`](file:///Users/brunobarbosa/Projetos/mwm/mwm/Slate/SwitchOperation.m)**: Application switcher controller.
- **[`Slate/SnapshotOperation.{h,m}`](file:///Users/brunobarbosa/Projetos/mwm/mwm/Slate/SnapshotOperation.m)**, **[`Slate/ActivateSnapshotOperation.{h,m}`](file:///Users/brunobarbosa/Projetos/mwm/mwm/Slate/ActivateSnapshotOperation.m)**, **[`Slate/DeleteSnapshotOperation.{h,m}`](file:///Users/brunobarbosa/Projetos/mwm/mwm/Slate/DeleteSnapshotOperation.m)**: Snapshot capture and restore.
- **[`Slate/Snapshot.{h,m}`](file:///Users/brunobarbosa/Projetos/mwm/mwm/Slate/Snapshot.m)**, **[`Slate/SnapshotList.{h,m}`](file:///Users/brunobarbosa/Projetos/mwm/mwm/Slate/SnapshotList.m)**, **[`Slate/WindowSnapshot.{h,m}`](file:///Users/brunobarbosa/Projetos/mwm/mwm/Slate/WindowSnapshot.m)**: Snapshot data models.
- **[`Slate/UndoOperation.{h,m}`](file:///Users/brunobarbosa/Projetos/mwm/mwm/Slate/UndoOperation.m)**: Undo stack pop and execution.
- **[`Slate/ShellOperation.{h,m}`](file:///Users/brunobarbosa/Projetos/mwm/mwm/Slate/ShellOperation.m)**: `/bin/sh` process execution.
- **[`Slate/VisibilityOperation.{h,m}`](file:///Users/brunobarbosa/Projetos/mwm/mwm/Slate/VisibilityOperation.m)**: App hide/show/toggle.
- **[`Slate/RelaunchOperation.{h,m}`](file:///Users/brunobarbosa/Projetos/mwm/mwm/Slate/RelaunchOperation.m)**: Restart application.
- **[`Slate/JSOperation.{h,m}`](file:///Users/brunobarbosa/Projetos/mwm/mwm/Slate/JSOperation.m)**: JavaScript callback invoker as an operation.

### JavaScript Scripting Engine
- **[`Slate/JSController.{h,m}`](file:///Users/brunobarbosa/Projetos/mwm/mwm/Slate/JSController.m)**: Bridge between Objective-C and JavaScriptCore via `WebView`.
- **[`Slate/initialize.js`](file:///Users/brunobarbosa/Projetos/mwm/mwm/Slate/initialize.js)**: Sets up `window.slate` / `window.S`.
- **[`Slate/utils.js`](file:///Users/brunobarbosa/Projetos/mwm/mwm/Slate/utils.js)** & **[`Slate/underscore.js`](file:///Users/brunobarbosa/Projetos/mwm/mwm/Slate/underscore.js)**: JS helper functions.
- **[`Slate/JSWindowWrapper.{h,m}`](file:///Users/brunobarbosa/Projetos/mwm/mwm/Slate/JSWindowWrapper.m)**: Window object exposed to JS.
- **[`Slate/JSApplicationWrapper.{h,m}`](file:///Users/brunobarbosa/Projetos/mwm/mwm/Slate/JSApplicationWrapper.m)**: Application object exposed to JS.
- **[`Slate/JSScreenWrapper.{h,m}`](file:///Users/brunobarbosa/Projetos/mwm/mwm/Slate/JSScreenWrapper.m)**: Screen object exposed to JS.
- **[`Slate/JSInfoWrapper.{h,m}`](file:///Users/brunobarbosa/Projetos/mwm/mwm/Slate/JSInfoWrapper.m)**: Global helper methods on `slate`.
- **[`Slate/JSOperationWrapper.{h,m}`](file:///Users/brunobarbosa/Projetos/mwm/mwm/Slate/JSOperationWrapper.m)**: Operation object returned in JS.
- **[`Slate/JSWrapperUtils.{h,m}`](file:///Users/brunobarbosa/Projetos/mwm/mwm/Slate/JSWrapperUtils.m)**: Type conversion utilities between Obj-C and WebScript objects.
- **[`Slate/slate-mock.js`](file:///Users/brunobarbosa/Projetos/mwm/mwm/Slate/slate-mock.js)** & **[`Slate/slate-test.html`](file:///Users/brunobarbosa/Projetos/mwm/mwm/Slate/slate-test.html)**: Test harness for JS configs in a standard browser.

### UI & Overlays
- **[`Slate/GridWindow.{h,m}`](file:///Users/brunobarbosa/Projetos/mwm/mwm/Slate/GridWindow.m)**, **[`Slate/GridView.{h,m}`](file:///Users/brunobarbosa/Projetos/mwm/mwm/Slate/GridView.m)**, **[`Slate/GridCellView.{h,m}`](file:///Users/brunobarbosa/Projetos/mwm/mwm/Slate/GridCellView.m)**: Visual interactive grid overlay.
- **[`Slate/HintWindow.{h,m}`](file:///Users/brunobarbosa/Projetos/mwm/mwm/Slate/HintWindow.m)**, **[`Slate/HintView.{h,m}`](file:///Users/brunobarbosa/Projetos/mwm/mwm/Slate/HintView.m)**: Window hint badges.
- **[`Slate/SwitchWindow.{h,m}`](file:///Users/brunobarbosa/Projetos/mwm/mwm/Slate/SwitchWindow.m)**, **[`Slate/SwitchView.{h,m}`](file:///Users/brunobarbosa/Projetos/mwm/mwm/Slate/SwitchView.m)**, **[`Slate/SwitchAppView.{h,m}`](file:///Users/brunobarbosa/Projetos/mwm/mwm/Slate/SwitchAppView.m)**, **[`Slate/SwitchAppQuittingOverlayView.{h,m}`](file:///Users/brunobarbosa/Projetos/mwm/mwm/Slate/SwitchAppQuittingOverlayView.m)**: App switcher HUD.

### Parser & Utilities
- **[`Slate/StringTokenizer.{h,m}`](file:///Users/brunobarbosa/Projetos/mwm/mwm/Slate/StringTokenizer.m)**: Command and expression tokenizer respecting quotes and delimiters.
- **[`Slate/MathUtils.{h,m}`](file:///Users/brunobarbosa/Projetos/mwm/mwm/Slate/MathUtils.m)**: Geometry math, rectangle intersections, and coordinate inversion.
- **[`Slate/ExpressionPoint.{h,m}`](file:///Users/brunobarbosa/Projetos/mwm/mwm/Slate/ExpressionPoint.m)**: Mathematical expression evaluation via `NSExpression`.
- **[`Slate/Binding.{h,m}`](file:///Users/brunobarbosa/Projetos/mwm/mwm/Slate/Binding.m)**: Keystroke-to-operation map; translates key strings to keycodes and modifiers.
- **[`Slate/ApplicationOptions.{h,m}`](file:///Users/brunobarbosa/Projetos/mwm/mwm/Slate/ApplicationOptions.m)**: Model for layout matching options (`mainFirst`, `repeat`, etc.).
- **[`Slate/NSString+Levenshtein.{h,m}`](file:///Users/brunobarbosa/Projetos/mwm/mwm/Slate/NSString+Levenshtein.m)**: Dynamic programming Levenshtein string distance for window title matching.
- **[`Slate/NSString+Indicies.{h,m}`](file:///Users/brunobarbosa/Projetos/mwm/mwm/Slate/NSString+Indicies.m)**: Character indexing helpers.
- **[`Slate/JSONKit/JSONKit.{h,m}`](file:///Users/brunobarbosa/Projetos/mwm/mwm/Slate/JSONKit/JSONKit.m)**: Fast embedded JSON parser and serializer.
- Keyboard Plist Mappings:
  - [`Slate/ASCIIToCode.plist`](file:///Users/brunobarbosa/Projetos/mwm/mwm/Slate/ASCIIToCode.plist): Standard QWERTY keycode mapping.
  - [`Slate/ASCIIToCode_Dvorak.plist`](file:///Users/brunobarbosa/Projetos/mwm/mwm/Slate/ASCIIToCode_Dvorak.plist): Dvorak layout mapping.
  - [`Slate/ASCIIToCode_Colemak.plist`](file:///Users/brunobarbosa/Projetos/mwm/mwm/Slate/ASCIIToCode_Colemak.plist): Colemak layout mapping.
  - [`Slate/ASCIIToCode_Azerty.plist`](file:///Users/brunobarbosa/Projetos/mwm/mwm/Slate/ASCIIToCode_Azerty.plist): AZERTY layout mapping.

---

## 2. Unit Testing Suite (`SlateTests`)

Located in [`SlateTests/`](file:///Users/brunobarbosa/Projetos/mwm/mwm/SlateTests), testing key utility engines using OCUnit:
- **`TestStringTokenizer.m`**: Verifies whitespace splitting, single/double quote handling, pipe-delimiters, and max-token limits.
- **`TestMathUtils.m`**: Tests rectangle intersection sizing, scaling factor multiplications, coordinate flipping across multiple monitor geometries.
- **`TestExpressionPoint.m`**: Tests math formula evaluation, variable substitution (`screenSizeX`, `windowTopLeftY`), math functions (`min`, `max`, `sum`, `floor`).
- **`TestNSString+Levenshtein.m`**: Validates edit distance calculations for fuzzy window title matching.
- **`TestNSString+Indicies.m`**: Tests character index search functions.
- **`TestShellUtils.m`**: Tests argument escaping and process execution logic.

---

## 3. Build & Packaging Automation

- **[`script/slate.rb`](file:///Users/brunobarbosa/Projetos/mwm/mwm/script/slate.rb)**: Ruby release orchestration script:
  - Tasks:
    - `gen`: Generates release builds.
    - `pub`: Publishes updates to the web server and appcast XML feed.
    - `dmg`: Bundles the application into `Slate.dmg` using `create-dmg` with custom background image (`build/dmg_background.png`) and application icon (`Slate/icon.icns`).
- **Updates**: there's no automatic updater; new versions are installed from a DMG.

