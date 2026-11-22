# Codebase Walkthrough & Internals

This document provides a component-by-component, file-by-file guide to the Slate codebase.

---

## 1. File & Component Manifest

### Core Application
- **[`MWM/main.m`](file:///Users/brunobarbosa/Projetos/mwm/mwm/MWM/main.m)**: Process entry point; invokes `NSApplicationMain`.
- **[`MWM/MWMAppDelegate.{h,m}`](file:///Users/brunobarbosa/Projetos/mwm/mwm/MWM/MWMAppDelegate.m)**: App delegate; coordinates status bar item, hotkey registration, Quartz event taps, modal input handling, login items, and the status and app menus (built in code).
- **[`MWM/MWMConfig.{h,m}`](file:///Users/brunobarbosa/Projetos/mwm/mwm/MWM/MWMConfig.m)**: Configuration engine; parses `.slate` directives, aliases, and layouts; manages snapshot persistence.
- **[`MWM/Constants.{h,m}`](file:///Users/brunobarbosa/Projetos/mwm/mwm/MWM/Constants.m)**: Central definitions of all string constants, config keys, default values, and token identifiers.
- **[`MWM/MWMLogger.h`](file:///Users/brunobarbosa/Projetos/mwm/mwm/MWM/MWMLogger.h)**: Logging macro abstractions (`MWMLogger`).
- **[`MWM/NSFileManager+ApplicationSupport.{h,m}`](file:///Users/brunobarbosa/Projetos/mwm/mwm/MWM/NSFileManager+ApplicationSupport.m)**: Category to resolve and ensure `~/Library/Application Support/Slate`.

### Window & Screen Abstraction
- **[`MWM/AccessibilityWrapper.{h,m}`](file:///Users/brunobarbosa/Projetos/mwm/mwm/MWM/AccessibilityWrapper.m)**: Core wrapper around macOS Accessibility APIs (`AXUIElementRef`, `AXObserverRef`). Reads and writes window positions and sizes, inspects roles, brings windows to front, and conducts hit-testing.
- **[`MWM/ScreenWrapper.{h,m}`](file:///Users/brunobarbosa/Projetos/mwm/mwm/MWM/ScreenWrapper.m)**: Manages multi-monitor geometries, coordinate system flipping (Cocoa bottom-left to AX top-left), and monitor resolution/direction matching.
- **[`MWM/RunningApplications.{h,m}`](file:///Users/brunobarbosa/Projetos/mwm/mwm/MWM/RunningApplications.m)**: Live registry of active applications and their open windows via `NSWorkspace` notifications and `AXObserver` callbacks.
- **[`MWM/WindowState.{h,m}`](file:///Users/brunobarbosa/Projetos/mwm/mwm/MWM/WindowState.m)**: Value object encapsulating snapshot state (PID, position, size) of a window.
- **[`MWM/ScreenState.{h,m}`](file:///Users/brunobarbosa/Projetos/mwm/mwm/MWM/ScreenState.m)**: Encapsulates monitor layout rules and resolution match conditions.

### Operation Hierarchy
- **[`MWM/Operation.{h,m}`](file:///Users/brunobarbosa/Projetos/mwm/mwm/MWM/Operation.m)**: Abstract base class providing lifecycle hooks (`initOptions:`, `evalOptions:`, `doOperation`, `testOperation`).
- **[`MWM/MoveOperation.{h,m}`](file:///Users/brunobarbosa/Projetos/mwm/mwm/MWM/MoveOperation.m)**: Core position & size mutator.
- **[`MWM/PushOperation.{h,m}`](file:///Users/brunobarbosa/Projetos/mwm/mwm/MWM/PushOperation.m)**: Edge push with optional bar and center styles.
- **[`MWM/ResizeOperation.{h,m}`](file:///Users/brunobarbosa/Projetos/mwm/mwm/MWM/ResizeOperation.m)**: Relative resizing with corner anchoring.
- **[`MWM/NudgeOperation.{h,m}`](file:///Users/brunobarbosa/Projetos/mwm/mwm/MWM/NudgeOperation.m)**: Offset translation.
- **[`MWM/CornerOperation.{h,m}`](file:///Users/brunobarbosa/Projetos/mwm/mwm/MWM/CornerOperation.m)**: Snap-to-corner positioning.
- **[`MWM/ThrowOperation.{h,m}`](file:///Users/brunobarbosa/Projetos/mwm/mwm/MWM/ThrowOperation.m)**: Monitor-to-monitor window movement.
- **[`MWM/FocusOperation.{h,m}`](file:///Users/brunobarbosa/Projetos/mwm/mwm/MWM/FocusOperation.m)**: Geometric directional focus (`left`, `right`, `above`, `below`, `behind`).
- **[`MWM/LayoutOperation.{h,m}`](file:///Users/brunobarbosa/Projetos/mwm/mwm/MWM/LayoutOperation.m)** & **[`MWM/Layout.{h,m}`](file:///Users/brunobarbosa/Projetos/mwm/mwm/MWM/Layout.m)**: Multi-app layout engine with regex title matching and window sequencing.
- **[`MWM/ChainOperation.{h,m}`](file:///Users/brunobarbosa/Projetos/mwm/mwm/MWM/ChainOperation.m)**: Successive operation cycling.
- **[`MWM/SequenceOperation.{h,m}`](file:///Users/brunobarbosa/Projetos/mwm/mwm/MWM/SequenceOperation.m)**: Compound multi-operation execution.
- **[`MWM/GridOperation.{h,m}`](file:///Users/brunobarbosa/Projetos/mwm/mwm/MWM/GridOperation.m)**: Interactive grid invoker.
- **[`MWM/HintOperation.{h,m}`](file:///Users/brunobarbosa/Projetos/mwm/mwm/MWM/HintOperation.m)**: Window hint overlay controller.
- **[`MWM/SwitchOperation.{h,m}`](file:///Users/brunobarbosa/Projetos/mwm/mwm/MWM/SwitchOperation.m)**: Application switcher controller.
- **[`MWM/SnapshotOperation.{h,m}`](file:///Users/brunobarbosa/Projetos/mwm/mwm/MWM/SnapshotOperation.m)**, **[`MWM/ActivateSnapshotOperation.{h,m}`](file:///Users/brunobarbosa/Projetos/mwm/mwm/MWM/ActivateSnapshotOperation.m)**, **[`MWM/DeleteSnapshotOperation.{h,m}`](file:///Users/brunobarbosa/Projetos/mwm/mwm/MWM/DeleteSnapshotOperation.m)**: Snapshot capture and restore.
- **[`MWM/Snapshot.{h,m}`](file:///Users/brunobarbosa/Projetos/mwm/mwm/MWM/Snapshot.m)**, **[`MWM/SnapshotList.{h,m}`](file:///Users/brunobarbosa/Projetos/mwm/mwm/MWM/SnapshotList.m)**, **[`MWM/WindowSnapshot.{h,m}`](file:///Users/brunobarbosa/Projetos/mwm/mwm/MWM/WindowSnapshot.m)**: Snapshot data models.
- **[`MWM/UndoOperation.{h,m}`](file:///Users/brunobarbosa/Projetos/mwm/mwm/MWM/UndoOperation.m)**: Undo stack pop and execution.
- **[`MWM/ShellOperation.{h,m}`](file:///Users/brunobarbosa/Projetos/mwm/mwm/MWM/ShellOperation.m)**: `/bin/sh` process execution.
- **[`MWM/VisibilityOperation.{h,m}`](file:///Users/brunobarbosa/Projetos/mwm/mwm/MWM/VisibilityOperation.m)**: App hide/show/toggle.
- **[`MWM/RelaunchOperation.{h,m}`](file:///Users/brunobarbosa/Projetos/mwm/mwm/MWM/RelaunchOperation.m)**: Restart application.
- **[`MWM/JSOperation.{h,m}`](file:///Users/brunobarbosa/Projetos/mwm/mwm/MWM/JSOperation.m)**: JavaScript callback invoker as an operation.

### JavaScript Scripting Engine
- **[`MWM/JSController.{h,m}`](file:///Users/brunobarbosa/Projetos/mwm/mwm/MWM/JSController.m)**: Bridge between Objective-C and JavaScriptCore via `WebView`.
- **[`MWM/initialize.js`](file:///Users/brunobarbosa/Projetos/mwm/mwm/MWM/initialize.js)**: Sets up `window.slate` / `window.S`.
- **[`MWM/utils.js`](file:///Users/brunobarbosa/Projetos/mwm/mwm/MWM/utils.js)** & **[`MWM/underscore.js`](file:///Users/brunobarbosa/Projetos/mwm/mwm/MWM/underscore.js)**: JS helper functions.
- **[`MWM/JSWindowWrapper.{h,m}`](file:///Users/brunobarbosa/Projetos/mwm/mwm/MWM/JSWindowWrapper.m)**: Window object exposed to JS.
- **[`MWM/JSApplicationWrapper.{h,m}`](file:///Users/brunobarbosa/Projetos/mwm/mwm/MWM/JSApplicationWrapper.m)**: Application object exposed to JS.
- **[`MWM/JSScreenWrapper.{h,m}`](file:///Users/brunobarbosa/Projetos/mwm/mwm/MWM/JSScreenWrapper.m)**: Screen object exposed to JS.
- **[`MWM/JSInfoWrapper.{h,m}`](file:///Users/brunobarbosa/Projetos/mwm/mwm/MWM/JSInfoWrapper.m)**: Global helper methods on `slate`.
- **[`MWM/JSOperationWrapper.{h,m}`](file:///Users/brunobarbosa/Projetos/mwm/mwm/MWM/JSOperationWrapper.m)**: Operation object returned in JS.
- **[`MWM/JSWrapperUtils.{h,m}`](file:///Users/brunobarbosa/Projetos/mwm/mwm/MWM/JSWrapperUtils.m)**: Type conversion utilities between Obj-C and WebScript objects.
- **[`MWM/slate-mock.js`](file:///Users/brunobarbosa/Projetos/mwm/mwm/MWM/slate-mock.js)** & **[`MWM/slate-test.html`](file:///Users/brunobarbosa/Projetos/mwm/mwm/MWM/slate-test.html)**: Test harness for JS configs in a standard browser.

### UI & Overlays
- **[`MWM/GridWindow.{h,m}`](file:///Users/brunobarbosa/Projetos/mwm/mwm/MWM/GridWindow.m)**, **[`MWM/GridView.{h,m}`](file:///Users/brunobarbosa/Projetos/mwm/mwm/MWM/GridView.m)**, **[`MWM/GridCellView.{h,m}`](file:///Users/brunobarbosa/Projetos/mwm/mwm/MWM/GridCellView.m)**: Visual interactive grid overlay.
- **[`MWM/HintWindow.{h,m}`](file:///Users/brunobarbosa/Projetos/mwm/mwm/MWM/HintWindow.m)**, **[`MWM/HintView.{h,m}`](file:///Users/brunobarbosa/Projetos/mwm/mwm/MWM/HintView.m)**: Window hint badges.
- **[`MWM/SwitchWindow.{h,m}`](file:///Users/brunobarbosa/Projetos/mwm/mwm/MWM/SwitchWindow.m)**, **[`MWM/SwitchView.{h,m}`](file:///Users/brunobarbosa/Projetos/mwm/mwm/MWM/SwitchView.m)**, **[`MWM/SwitchAppView.{h,m}`](file:///Users/brunobarbosa/Projetos/mwm/mwm/MWM/SwitchAppView.m)**, **[`MWM/SwitchAppQuittingOverlayView.{h,m}`](file:///Users/brunobarbosa/Projetos/mwm/mwm/MWM/SwitchAppQuittingOverlayView.m)**: App switcher HUD.

### Parser & Utilities
- **[`MWM/StringTokenizer.{h,m}`](file:///Users/brunobarbosa/Projetos/mwm/mwm/MWM/StringTokenizer.m)**: Command and expression tokenizer respecting quotes and delimiters.
- **[`MWM/MathUtils.{h,m}`](file:///Users/brunobarbosa/Projetos/mwm/mwm/MWM/MathUtils.m)**: Geometry math, rectangle intersections, and coordinate inversion.
- **[`MWM/ExpressionPoint.{h,m}`](file:///Users/brunobarbosa/Projetos/mwm/mwm/MWM/ExpressionPoint.m)**: Mathematical expression evaluation via `NSExpression`.
- **[`MWM/Binding.{h,m}`](file:///Users/brunobarbosa/Projetos/mwm/mwm/MWM/Binding.m)**: Keystroke-to-operation map; translates key strings to keycodes and modifiers.
- **[`MWM/ApplicationOptions.{h,m}`](file:///Users/brunobarbosa/Projetos/mwm/mwm/MWM/ApplicationOptions.m)**: Model for layout matching options (`mainFirst`, `repeat`, etc.).
- **[`MWM/NSString+Levenshtein.{h,m}`](file:///Users/brunobarbosa/Projetos/mwm/mwm/MWM/NSString+Levenshtein.m)**: Dynamic programming Levenshtein string distance for window title matching.
- **[`MWM/NSString+Indicies.{h,m}`](file:///Users/brunobarbosa/Projetos/mwm/mwm/MWM/NSString+Indicies.m)**: Character indexing helpers.
- **[`MWM/JSONKit/JSONKit.{h,m}`](file:///Users/brunobarbosa/Projetos/mwm/mwm/MWM/JSONKit/JSONKit.m)**: Fast embedded JSON parser and serializer.
- Keyboard Plist Mappings:
  - [`MWM/ASCIIToCode.plist`](file:///Users/brunobarbosa/Projetos/mwm/mwm/MWM/ASCIIToCode.plist): Standard QWERTY keycode mapping.
  - [`MWM/ASCIIToCode_Dvorak.plist`](file:///Users/brunobarbosa/Projetos/mwm/mwm/MWM/ASCIIToCode_Dvorak.plist): Dvorak layout mapping.
  - [`MWM/ASCIIToCode_Colemak.plist`](file:///Users/brunobarbosa/Projetos/mwm/mwm/MWM/ASCIIToCode_Colemak.plist): Colemak layout mapping.
  - [`MWM/ASCIIToCode_Azerty.plist`](file:///Users/brunobarbosa/Projetos/mwm/mwm/MWM/ASCIIToCode_Azerty.plist): AZERTY layout mapping.

---

## 2. Unit Testing Suite (`MWMTests`)

Located in [`MWMTests/`](file:///Users/brunobarbosa/Projetos/mwm/mwm/MWMTests), testing key utility engines using OCUnit:
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
    - `dmg`: Bundles the application into `MWM.dmg` using `create-dmg` with custom background image (`build/dmg_background.png`) and application icon (`MWM/Resources/icon.icns`).
- **Updates**: there's no automatic updater; new versions are installed from a DMG.

