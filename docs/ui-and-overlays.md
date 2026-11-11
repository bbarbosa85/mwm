# UI Components & Overlays

Slate provides several rich, semi-transparent HUD overlays rendered directly on screen above other windows.

---

## 1. Interactive Grid (`GridWindow`, `GridView`, `GridCellView`)

The Grid feature allows users to position and resize windows visually using mouse dragging across a subdivided grid matrix.

### Architecture:
- [`GridWindow`](file:///Users/brunobarbosa/Projetos/mwm/mwm/Slate/GridWindow.m): A borderless `NSWindow` with `NSScreenSaverWindowLevel - 1`, set to floating and translucent (`backgroundColor = clearColor`).
- [`GridView`](file:///Users/brunobarbosa/Projetos/mwm/mwm/Slate/GridView.m): The container canvas view that manages matrix subdivisions, tracking mouse-down and mouse-drag selection rectangles.
- [`GridCellView`](file:///Users/brunobarbosa/Projetos/mwm/mwm/Slate/GridCellView.m): Individual cells that visually toggle highlight colors (`gridCellBackgroundColor` vs. `gridCellSelectedColor`) when the mouse sweeps across them.

### Invocation Syntax:
```
grid [padding:<int>] [screenRef:cols,rows]
```
Example:
```
# 12x12 grid by default, with custom resolutions
bind g:ctrl;cmd grid padding:5 1920x1080:16,9 2560x1440:24,14
```

### Usage:
1. Triggering the shortcut displays grid overlays on all monitors.
2. Clicking and dragging across cells selects a span of grid blocks.
3. Releasing the mouse instantly moves and resizes the focused window to match the dragged cell boundaries.
4. Pressing `Esc` closes the grid without making changes.

---

## 2. Window Hints (`HintWindow`, `HintView`)

Inspired by Vimium / Vimperator link hints, Window Hints overlay quick jump letters on every visible window on screen.

### Architecture & Collision Avoidance:
- [`HintWindow`](file:///Users/brunobarbosa/Projetos/mwm/mwm/Slate/HintWindow.m): Lightweight transparent window created for each candidate window.
- [`HintView`](file:///Users/brunobarbosa/Projetos/mwm/mwm/Slate/HintView.m): Draws the rounded badge, letter text, and optional application icon.
- **Collision Avoidance ("Spread Algorithm")**:
  - When multiple windows overlap closely (e.g. cascaded terminal windows), standard badge placement at the center or top-left causes badges to overlap, obscuring characters.
  - When `windowHintsSpread true` is enabled, Slate performs a spiral 2D collision search around the desired badge anchor:
    ```c
    // From HintOperation.m:
    // Evaluates potential bounding box intersections and shifts hint badges
    // by spreadPadding until a non-colliding location on screen is found.
    ```
- **Ordering Strategies (`windowHintsOrder`)**:
  - `leftToRight`: Sorts windows left-to-right before assigning hint letters.
  - `rightToLeft`: Right-to-left assignment.
  - `persist`: Maintains character assignment consistency across invocations.

### Keybindings & Exit:
- Pressing the matching letter key instantly activates and raises that window.
- Pressing `Esc` or clicking elsewhere dismisses the hints overlay.
- `windowHintsDuration` automatically fades hints after inactivity.

---

## 3. Application Switcher (`SwitchWindow`, `SwitchView`, `SwitchAppView`)

Slate includes a full replacement for macOS's built-in `Cmd+Tab` switcher.

### Features:
1. **Interactive Layouts**:
   - Configurable orientation: horizontal bar or vertical list (`switchOrientation`).
   - Displays application icons, badges, and optionally window titles (`switchShowTitles`).
2. **In-Switcher Management Keystrokes**:
   - While holding `Cmd` and navigating through applications, users can press:
     - **`q`**: Marks the highlighted application for termination.
     - **`f`**: Marks the highlighted application for immediate force-kill.
     - **`h`**: Toggles hide on the selected application.
     - **`` ` `` (Backtick)**: Reverses direction through the switcher list.
3. **Quitting Overlay**:
   - Applications marked for quit display an animated, red cross-out overlay ([`SwitchAppQuittingOverlayView`](file:///Users/brunobarbosa/Projetos/mwm/mwm/Slate/SwitchAppQuittingOverlayView.m)).
   - Actions execute as soon as the user releases the `Cmd` modifier.

---

## 4. Configuration Window

- **Configure Slate…** (⌘,) in the status menu opens a form for `~/.slate.yml`. See [Configuration File](configuration-yaml.md).

