# Classic Configuration Guide (`.slate`)

Slate is configured using a plain-text configuration file located at `~/.slate`. If no `~/.slate` or `~/.slate.js` is found upon launch, Slate loads its built-in fallback configuration ([`Slate/default.slate`](file:///Users/brunobarbosa/Projetos/mwm/mwm/Slate/default.slate)).

---

## Directives Overview

A `.slate` file is parsed line-by-line and supports the following top-level directives:

| Directive | Purpose | Example |
| :--- | :--- | :--- |
| `config` | Sets a global or app-specific configuration option | `config defaultToCurrentScreen true` |
| `alias` | Defines reusable macro text variables | `alias hyper ctrl;alt;cmd` |
| `layout` | Defines multi-window / multi-screen application layouts | `layout dev 'iTerm' push left bar-resize:screenSizeX/2` |
| `default` | Binds a monitor setup to an auto-activating layout or snapshot | `default dev count:2` |
| `bind` | Associates a keystroke or modal key with an operation | `bind right:${hyper} push right bar-resize:screenSizeX/2` |
| `source` | Imports another `.slate` configuration file | `source ~/.slate.local if_exists` |

> [!NOTE]
> `#` is the comment character. Any text following `#` on a line is ignored. Lines are read sequentially from top to bottom.

---

## 1. Expressions & Math Evaluator

Slate contains a built-in mathematical expression engine. Wherever coordinate values or dimensions are expected, dynamic expressions can be used instead of hardcoded numbers.

> [!IMPORTANT]
> **No whitespace inside expressions:** Because Slate's tokenizer separates parameters by whitespace, expressions must not contain spaces (e.g. `screenSizeX/2` is valid, `screenSizeX / 2` will fail).

### Available Expression Variables

| Variable | Description | Where Available |
| :--- | :--- | :--- |
| `screenOriginX` | Top-left X coordinate of the target monitor | `move`, `push`, `corner`, `throw` |
| `screenOriginY` | Top-left Y coordinate of the target monitor | `move`, `push`, `corner`, `throw` |
| `screenSizeX` | Width of the target monitor | All geometric operations |
| `screenSizeY` | Height of the target monitor | All geometric operations |
| `windowTopLeftX` | Current top-left X coordinate of the target window | `move`, `nudge`, `resize` |
| `windowTopLeftY` | Current top-left Y coordinate of the target window | `move`, `nudge`, `resize` |
| `windowSizeX` | Current width of the target window | All geometric operations |
| `windowSizeY` | Current height of the target window | All geometric operations |
| `newWindowSizeX` | Target window width after resize | Only in `topLeftX` & `topLeftY` |
| `newWindowSizeY` | Target window height after resize | Only in `topLeftX` & `topLeftY` |
| `windowHintsWidth` | Value of `windowHintsWidth` config | Only in hint offset expressions |
| `windowHintsHeight`| Value of `windowHintsHeight` config | Only in hint offset expressions |

### Operators and Mathematical Functions
Powered by Foundation's `NSExpression`:
- Arithmetic: `+`, `-`, `*`, `/`, `**` (exponentiation)
- Functions: `min({a,b})`, `max({a,b})`, `sum({a,b})`, `average({a,b})`, `median({a,b})`
- Rounding: `floor(x)`, `ceiling(x)`, `trunc(x)`, `abs(x)`
- Exponentials & Logarithms: `sqrt(x)`, `log(x)` (base 10), `ln(x)` (natural log), `exp(x)` ($e^x$)
- Randomness: `random()` (float $[0, 1)$), `randomn(N)` (integer $[0, N-1]$)

---

## 2. Key Bindings (`bind`)

### Standard Syntax
```
bind key:modifiers operation [parameters]
```

### Modifiers
Multiple modifiers can be separated by `,` or `;`:
- `ctrl` (Control)
- `alt` (Option / Alt)
- `cmd` (Command)
- `shift` (Shift)
- `fn` (Function)

### Modal Bindings
Modal bindings allow defining "leader" or "sub-mode" key sequences:
```
bind activation_key:activation_modifiers modal_key [parameters]
```
Example:
```
# Press Ctrl+Shift+Space to enter modal mode, then press 'h' to push left:
bind h:ctrl;shift;space push left bar-resize:screenSizeX/2

# Modal toggle: persists mode until explicitly exited or toggled off:
bind h:ctrl;shift;space:toggle push left bar-resize:screenSizeX/2
```
To exit modal mode manually:
- Re-press the modal trigger.
- Configure `modalEscapeKey` (e.g. `config modalEscapeKey esc`).

---

## 3. Layouts & Display Defaults

### Layout Declaration
```
layout <name> '<app_name>':OPTIONS <operations_list>
```
Multiple operations can be piped with `|` to manage multiple windows belonging to the same application:
```
layout dev 'Google Chrome':MAIN_FIRST push left bar-resize:screenSizeX/2 | push right bar-resize:screenSizeX/2
layout dev 'iTerm':REPEAT push right bar-resize:screenSizeX/2
layout dev BEFORE shell path:~/ 'echo Layout starting'
layout dev AFTER shell path:~/ 'echo Layout finished'
```

### Application Layout Options
- `IGNORE_FAIL`: Continues to the next window/operation if one fails.
- `REPEAT`: Cycles through operations if there are more windows than operations.
- `REPEAT_LAST`: Repeats the final operation for any extra windows.
- `MAIN_FIRST`: Assigns the main (active) window to the first operation.
- `MAIN_LAST`: Assigns the main window to the last operation.
- `SORT_TITLE`: Sorts windows alphabetically by title before applying operations.
- `TITLE_ORDER=t1;t2`: Matches windows matching specific titles in order.
- `TITLE_ORDER_REGEX=r1;r2`: Matches windows matching regex patterns in order.

### Screen Defaults (`default`)
Auto-activates a layout or snapshot when display arrangements change:
```
# By monitor count:
default singleMonitorLayout count:1
default dualMonitorLayout count:2

# By monitor resolutions:
default devSetup resolutions:1920x1080;2560x1440
```

---

## 4. Application-Specific Configurations

Global configs can be targeted at specific applications by appending `:<app_name>` to the key:
```
config nudgePercentOf:iTerm windowSize
config nudgePercentOf screenSize
```

---

## 5. Complete Global Configurations Reference

| Key | Default Value | Description |
| :--- | :--- | :--- |
| `defaultToCurrentScreen` | `false` | Fall back to current screen if specified screen is unavailable |
| `orderScreensLeftToRight` | `true` | Index screens sequentially by X position instead of OS IDs |
| `nudgePercentOf` | `screenSize` | Reference dimension for percent nudges (`screenSize` or `windowSize`) |
| `resizePercentOf` | `screenSize` | Reference dimension for percent resizes (`screenSize` or `windowSize`) |
| `repeatOnHoldOps` | `resize,nudge` | Operations that repeat while holding hotkey |
| `secondsBeforeRepeat` | `0.4` | Initial delay before key repeat kicks in (seconds) |
| `secondsBetweenRepeat` | `0.2` | Interval between repeat iterations (seconds) |
| `checkDefaultsOnLoad` | `false` | Evaluate and trigger default layouts when config loads |
| `focusCheckWidth` | `100` | Starting search radius for directional focus (pixels) |
| `focusCheckWidthMax` | `100` | Maximum search radius for directional focus (pixels) |
| `focusPreferSameApp` | `true` | Prefer focusing windows belonging to current app |
| `modalEscapeKey` | `""` | Keystroke that exits any active modal mode |
| `undoMaxStackSize` | `10` | Max snapshots kept in the undo history stack |
| `undoOps` | *(all movement ops)* | Operations that push to undo stack |
| `snapshotTitleMatch` | `levenshtein` | Window matching algorithm (`levenshtein` or `sequential`) |
| `snapshotMaxStackSize`| `0` (unlimited) | Max snapshots kept in named snapshot stacks |
| `keyboardLayout` | `qwerty` | Layout mapping (`qwerty`, `dvorak`, `colemak`, `azerty`) |
| `layoutFocusOnActivate`| `false` | Raise and focus apps in layout activation order |
| `windowHintsFontName` | `Helvetica` | Font face for window hint letter overlays |
| `windowHintsFontSize` | `40` | Font size for window hint letter overlays |
| `windowHintsFontColor` | `255;255;255;1.0`| RGBA font color for window hints |
| `windowHintsBackgroundColor` | `50;53;58;0.9` | RGBA background color for hint badges |
| `windowHintsWidth` | `100` | Width of hint badge (pixels) |
| `windowHintsHeight` | `100` | Height of hint badge (pixels) |
| `windowHintsDuration` | `3` | Timeout before hints automatically disappear (seconds) |
| `windowHintsRoundedCornerSize` | `5` | Corner radius of hint badges (pixels) |
| `windowHintsIgnoreHiddenWindows` | `true` | Do not place hints on minimized or hidden windows |
| `windowHintsShowIcons` | `false` | Show application icon alongside letter hint |
| `windowHintsSpread` | `false` | Dynamically shift hints to avoid overlapping badges |
| `switchIconSize` | `100` | Icon dimension in application switcher (pixels) |
| `switchBackgroundColor`| `50;53;58;0.3` | Background color of switcher overlay window |
| `switchSelectedBackgroundColor` | `50;53;58;0.9` | Background color of currently selected switcher item |
| `switchOrientation` | `horizontal` | Layout of switcher items (`horizontal` or `vertical`) |
| `switchType` | `app` | Item granuality in switcher (`app` or `window`) |
| `switchOnlyFocusMainWindow` | `true` | Focusing app in switcher focuses its main window only |
| `gridBackgroundColor` | `75;77;81;1.0` | Background of interactive screen grid |
| `gridCellBackgroundColor` | `100;106;116;0.8`| Color of unselected grid cells |
| `gridCellSelectedColor`| `50;53;58;0.8` | Color of cells inside mouse drag selection |

