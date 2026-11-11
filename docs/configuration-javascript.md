# JavaScript Scripting Guide (`.slate.js`)

> **MWM no longer loads `~/.slate.js`.** Configurations are data only, in [`~/.mwm.yml`](configuration-yaml.md); on startup MWM converts a `~/.slate.js` written by the earlier configuration window into it. This guide describes the JavaScript runtime, which is still part of the codebase but isn't reachable from a configuration file.

Slate's JavaScript runtime (`~/.slate.js`) offered programmatic scripting, dynamic calculation, conditional layouts, and event-driven automation.

---

## 1. Runtime Architecture

Slate embeds WebKit's JavaScript engine through a headless `WebView` managed by [`JSController`](file:///Users/brunobarbosa/Projetos/mwm/mwm/Slate/JSController.m).

```mermaid
flowchart LR
    JSFile["~/.slate.js"] --> JSController[JSController (WebView / JSContext)]
    JSController --> GlobalSlate["window.slate (alias: window.S)"]
    GlobalSlate --> Bridge["JSWrapperUtils (Marshalling / Unmarshalling)"]
    Bridge --> Wrappers["Obj-C Proxies (JSWindow, JSApplication, JSScreen)"]
```

When initializing, Slate loads:
1. **[`underscore.js`](file:///Users/brunobarbosa/Projetos/mwm/mwm/Slate/underscore.js)**: Full Underscore.js utility library (`_`).
2. **[`utils.js`](file:///Users/brunobarbosa/Projetos/mwm/mwm/Slate/utils.js)**: Helper functions for type checking and array/dictionary conversion.
3. **`Scripting/managed-config.js`**: Resolves the managed `config` object used by `slate.applyConfig` (see section 6).
4. **[`initialize.js`](file:///Users/brunobarbosa/Projetos/mwm/mwm/Slate/initialize.js)**: Creates the global `slate` (and shorthand `S`) object, binds methods, and connects callbacks.

---

## 2. Global `slate` API Reference

The global object is accessible via `slate` or shorthand `S`.

### Configuration
```javascript
// Set a configuration option
slate.config("defaultToCurrentScreen", true);

// Pass a callback function that evaluates dynamically!
slate.config("nudgePercentOf", function() {
  return "screenSize";
});

// Configure multiple options at once:
slate.configAll({
  "defaultToCurrentScreen": true,
  "orderScreensLeftToRight": true,
  "secondsBeforeRepeat": 0.3
});
```

### Key Bindings (`slate.bind`)
```javascript
// Bind a keystroke to a built-in operation
slate.bind("right:ctrl;alt", slate.operation("push", {
  "direction": "right",
  "style": "bar-resize:screenSizeX/2"
}));

// Bind a keystroke to a custom JavaScript function:
// (receives the focused window object as argument)
slate.bind("m:ctrl;cmd", function(win) {
  if (!win) return;
  var screen = win.screen().rect();
  win.move({
    x: screen.x + 50,
    y: screen.y + 50
  });
  win.resize({
    width: screen.width - 100,
    height: screen.height - 100
  });
});

// Bind all at once with slate.bindAll:
slate.bindAll({
  "left:ctrl;cmd": slate.operation("push", { "direction": "left" }),
  "right:ctrl;cmd": slate.operation("push", { "direction": "right" })
});
```

### Operations
```javascript
// Create an operation instance
var op = slate.operation("move", {
  "x": "screenOriginX",
  "y": "screenOriginY",
  "width": "screenSizeX/2",
  "height": "screenSizeY"
});

// Create an operation from classic string syntax:
var pushOp = slate.operationFromString("push left bar-resize:screenSizeX/3");

// Immediately execute an operation on the current window:
slate.doOperation("push", { "direction": "top" });
```

### Shell Commands
```javascript
// Run a shell command (command, wait, cwd)
slate.shell("git status", false, "~/myproject");
```

### Logging
```javascript
slate.log("Hello from Slate JS!");
```
Output is visible in system log (`/var/log/system.log` or Console.app).

---

## 3. Object Wrappers

### `Window` (`JSWindowWrapper`)
Methods on window instances:
- `win.title()`: Window title string.
- `win.rect()`: Returns `{ x, y, width, height }`.
- `win.topLeft()` (or `win.tl()`): Returns `{ x, y }`.
- `win.size()`: Returns `{ width, height }`.
- `win.pid()`: Process ID of host application.
- `win.focus()`: Focuses and raises the window.
- `win.isMinimizedOrHidden()` (or `win.hidden()`): Boolean.
- `win.isMovable()` (or `win.movable()`): Boolean.
- `win.isResizable()` (or `win.resizable()`): Boolean.
- `win.isMain()` (or `win.main()`): Whether this is the main window of the app.
- `win.move({ x, y })`: Moves window to coordinates.
- `win.resize({ width, height })`: Resizes window.
- `win.screen()`: Returns the `Screen` object enclosing this window.
- `win.app()`: Returns the parent `Application` object.
- `win.doOperation(op, [opts])`: Executes an operation on this window.

### `Application` (`JSApplicationWrapper`)
Methods on application instances:
- `app.name()`: Localized application name (e.g. `"Google Chrome"`).
- `app.pid()`: Process ID.
- `app.mainWindow()` (or `app.mwindow()`): Main `Window` instance.
- `app.eachWindow(funcOrOp)` (or `app.ewindow(...)`): Iterates through open windows.

### `Screen` (`JSScreenWrapper`)
Methods on screen instances:
- `screen.id()`: Slate screen reference ID.
- `screen.rect()`: Full screen rectangle `{ x, y, width, height }`.
- `screen.visibleRect()` (or `screen.vrect()`): Usable area excluding menu bar and dock.
- `screen.isMain()` (or `screen.main()`): Boolean.

### Global Info Utilities (`JSInfoWrapper`)
Available directly on `slate` / `S`:
- `slate.window()`: Currently focused window.
- `slate.app()`: Currently focused application.
- `slate.screen()`: Screen containing the currently focused window.
- `slate.screenCount()` (or `slate.screenc`): Number of connected displays.
- `slate.screenForRef(ref)`: Retrieves screen by ID, resolution, or direction.
- `slate.eachScreen(function(screen) { ... })`: Iterates over all screens.
- `slate.eachApp(function(app) { ... })`: Iterates over all running applications.
- `slate.windowUnderPoint({ x, y })`: Window beneath coordinate point.
- `slate.screenUnderPoint({ x, y })`: Screen beneath coordinate point.
- `slate.isPointOffScreen({ x, y })`: Boolean.
- `slate.isRectOffScreen({ x, y, width, height })`: Boolean.

---

## 4. Event System (`slate.on`)

Slate allows listening to OS workspace and window manager events:

```javascript
slate.on("event_name", function(payload) {
  // respond to event
});
```

### Event Catalog

| Event Name | Payload | Triggered When |
| :--- | :--- | :--- |
| `appOpened` | `Application` | A new application launches |
| `appClosed` | `Application` | An application terminates |
| `appHidden` | `Application` | An application is hidden |
| `appUnhidden` | `Application` | An application is shown |
| `appActivated` | `Application` | An application gains frontmost focus |
| `appDeactivated` | `Application` | An application loses frontmost focus |
| `windowOpened` | `Window` | A new window is created |
| `windowClosed` | `Application` | A window is destroyed |
| `windowFocused` | `Window` | Focused window changes |
| `windowTitleChanged` | `Window` | Window title changes |
| `windowMoved` | `Window` | Window position changes *(requires `jsReceiveMoveEvent true`)* |
| `windowResized` | `Window` | Window size changes *(requires `jsReceiveResizeEvent true`)* |
| `screenConfigurationChanged` | `null` | Monitors added/removed or resolution changed |

---

## 5. JavaScript Layouts & Screen Defaults

### Declarative Layouts
```javascript
slate.layout("codingLayout", {
  "_before_": {
    "operations": [slate.operation("shell", { "command": "echo 'Layout Start'" })]
  },
  "Google Chrome": {
    "operations": [slate.operation("push", { "direction": "left" })],
    "main-first": true,
    "repeat": true
  },
  "iTerm": {
    "operations": [slate.operation("push", { "direction": "right" })],
    "repeat": true
  }
});
```

### Dynamic Event Automation Example
```javascript
// Auto-center any new window when it opens
slate.on("windowOpened", function(win) {
  if (!win || !win.isResizable()) return;
  var screen = win.screen().visibleRect();
  win.move({
    x: screen.x + (screen.width - 1200) / 2,
    y: screen.y + (screen.height - 800) / 2
  });
  win.resize({ width: 1200, height: 800 });
});

// Auto-activate layout on monitor changes:
slate.default(2, slate.operation("layout", { "name": "codingLayout" }));
```

---
