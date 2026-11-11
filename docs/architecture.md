# System Architecture

Slate is an advanced, keyboard-driven window management system built for macOS. It interfaces deeply with the macOS operating system via low-level Cocoa, Carbon, Quartz (Core Graphics), and Accessibility (AX) APIs.

```mermaid
flowchart TD
    UserKeyboard[User Keyboard / Event Tap] -->|HotKey / Event Tap| SlateAppDelegate
    SlateAppDelegate -->|Dispatches Key / Modal Event| Binding
    Binding -->|Executes| Operation[Operation Hierarchy]
    Operation --> AccessibilityWrapper[AccessibilityWrapper (AXUIElementRef)]
    Operation --> ScreenWrapper[ScreenWrapper (NSScreen / Quartz)]
    AccessibilityWrapper -->|AX Actions| TargetWindows[macOS Window Server / Windows]

    subgraph Config Subsystem
        ConfigLoader[SlateConfig] -->|Parses ~/.slate| Directives[Directives / Bindings / Layouts]
        ConfigLoader -->|Loads ~/.slate.js| JSController[JSController / WebKit]
        JSController -->|Calls JS API| GlobalSlate[window.slate / window.S]
        GlobalSlate -->|Creates| JSOperation[JSOperationWrapper / Callbacks]
    end

    subgraph OS Event Monitoring
        Workspace[NSWorkspace] -->|App Events| RunningApplications
        AXObserver[AXObserverRef] -->|Window Events| RunningApplications
        QuartzDisplay[CGDisplayReconfiguration] -->|Display Changes| ScreenWrapper
        RunningApplications -->|Fires Callbacks| JSController
    end
```

---

## 1. Application Lifecycle & Delegate (`SlateAppDelegate`)

The central hub of Slate during runtime is [`SlateAppDelegate`](file:///Users/brunobarbosa/Projetos/mwm/mwm/Slate/SlateAppDelegate.m).

### Key Responsibilities:
1. **Status Item & Menu Management**: Runs Slate as a status-bar accessory application (`NSStatusItem`). The status menu offers "About Slate", "Configure Slate…", "Reload Configuration", "Launch Slate at Login" and "Quit Slate". Menus are built in code by `SlateAppDelegate` (there's no main nib); the app menus (Slate, Edit, Window) only show while a Slate window is in front.
2. **Configuration Loading**: Dispatches config loading to `[SlateConfig getInstance]`, handling fallback to the embedded `default.slate` if neither `~/.slate` nor `~/.slate.js` exists.
3. **Global HotKey Registration**: Uses the Carbon Event Manager (`RegisterEventHotKey`, `InstallEventHandler`) to bind global keystrokes system-wide.
4. **Modal HotKey Management**:
   - Supports modal states where an activation keystroke (e.g. `Ctrl+F4`) activates a temporary key-listening mode.
   - Updates the menu bar icon (`status.pdf` vs. `statusActive.pdf`) to signal that modal mode is active.
   - Binds sub-hotkeys dynamically, resetting upon single action execution or toggle exit.
5. **Key Repeat Handling**: Implements key repeating through synchronized `NSTimer` loops (`secondsBeforeRepeat` and `secondsBetweenRepeat`), enabling smooth continuous nudging and resizing when holding down a hotkey.
6. **Application Switcher Replacement**:
   - Slate can intercept standard macOS `Cmd+Tab` and `Cmd+Shift+Tab` keystrokes.
   - It installs a Quartz Event Tap (`CGEventTapCreate`, `kCGHeadInsertEventTap`) callback `EatAppSwitcherCallback` to swallow OS events and invoke Slate's custom `SwitchOperation`.

---

## 2. Accessibility Subsystem (`AccessibilityWrapper`)

Slate manipulates foreign applications and windows through the macOS Accessibility API (`ApplicationServices/HIServices/AXUIElement.h`).

### Core Abstractions:
- **`AXUIElementRef app`**: Accessibility element reference for the application owning the window.
- **`AXUIElementRef window`**: Accessibility element reference for the specific target window.

### Operations Implemented:
- **Geometry Retrieval**:
  - `AXUIElementCopyAttributeValue(window, kAXPositionAttribute, ...)`: Returns the window's top-left point.
  - `AXUIElementCopyAttributeValue(window, kAXSizeAttribute, ...)`: Returns window width and height.
- **Geometry Mutation**:
  - `AXUIElementSetAttributeValue(window, kAXPositionAttribute, AXValueCreate(kAXValueCGPointType, ...))`.
  - `AXUIElementSetAttributeValue(window, kAXSizeAttribute, AXValueCreate(kAXValueCGSizeType, ...))`.
- **Focus and Stacking**:
  - `AXUIElementPerformAction(window, kAXRaiseAction)`: Brings window to front.
  - `AXUIElementSetAttributeValue(app, kAXFocusedWindowAttribute, window)`: Sets active window focus.
  - `[NSRunningApplication activateWithOptions:NSApplicationActivateIgnoringOtherApps]`: Activates host process.
- **State Queries**:
  - Tests window minimization (`kAXMinimizedAttribute`), role (`kAXWindowRole`), subrole, and whether the window is movable or resizable.
- **Hit-Testing**:
  - `AXUIElementCopyElementAtPosition(systemWide, point.x, point.y, &element)`: Finds window under a specific cursor or screen position (`windowUnderPoint`).

---

## 3. Coordinate Systems & Screen Geometry (`ScreenWrapper`)

macOS features two conflicting coordinate systems:
1. **Cocoa Screen Coordinates (`NSScreen`)**:
   - Origin `(0, 0)` is at the **bottom-left** of the primary display.
   - Y coordinates increase **upwards**.
2. **Accessibility Window Coordinates (`AXUIElement`)**:
   - Origin `(0, 0)` is at the **top-left** of the primary display.
   - Y coordinates increase **downwards**.

### Coordinate Normalization
[`ScreenWrapper`](file:///Users/brunobarbosa/Projetos/mwm/mwm/Slate/ScreenWrapper.m) normalizes all screen bounds to accessibility window coordinates:

$$\text{windowY} = \text{primaryScreenHeight} - (\text{screenOriginY} + \text{screenHeight})$$

[`MathUtils flipYCoordinateOfRect:withReference:`](file:///Users/brunobarbosa/Projetos/mwm/mwm/Slate/MathUtils.m) executes this inversion cleanly across arbitrary displays.

### Display Ordering & Identification
Displays can be targeted using multiple conventions:
- **Left-to-Right Ordering (`orderScreensLeftToRight true`)**: Sorts all connected monitors by their X coordinates, then Y coordinates.
- **Internal OS Index (`0`, `1`, `2`)**: Order assigned by Core Graphics.
- **Explicit Prefix (`ordered:0`)**: Forces left-to-right indexing even if `orderScreensLeftToRight` is disabled.
- **Resolution String (`1920x1080`, `2560x1440`)**: Matches monitor by pixel dimensions.
- **Relative Direction (`left`, `right`, `above`, `below`, `next`, `previous`)**: Discovers adjacent screen based on geometry bounding boxes.

### Quartz Display Reconfiguration Callback
Slate monitors monitor plug/unplug and resolution change events using:
```c
CGDisplayRegisterReconfigurationCallback(onDisplayReconfiguration, (__bridge void *)(self));
```
When `kCGDisplayDesktopShapeChangedFlag` fires, Slate:
1. Refreshes cached screen geometries.
2. Evaluates `default` layout rules.
3. Fires `screenConfigurationChanged` events into the JavaScript engine.

---

## 4. Running Application & Window Tracking (`RunningApplications`)

[`RunningApplications`](file:///Users/brunobarbosa/Projetos/mwm/mwm/Slate/RunningApplications.m) acts as a live registry for all running macOS applications and their open windows.

### Mechanism:
- Subscribes to `NSWorkspace` notifications:
  - `NSWorkspaceDidLaunchApplicationNotification` (`appOpened`)
  - `NSWorkspaceDidTerminateApplicationNotification` (`appClosed`)
  - `NSWorkspaceDidHideApplicationNotification` (`appHidden`)
  - `NSWorkspaceDidUnhideApplicationNotification` (`appUnhidden`)
  - `NSWorkspaceDidActivateApplicationNotification` (`appActivated`)
  - `NSWorkspaceDidDeactivateApplicationNotification` (`appDeactivated`)
- Installs `AXObserverRef` hooks on running applications for granular window tracking:
  - `kAXWindowCreatedNotification` (`windowOpened`)
  - `kAXUIElementDestroyedNotification` (`windowClosed`)
  - `kAXFocusedWindowChangedNotification` (`windowFocused`)
  - `kAXTitleChangedNotification` (`windowTitleChanged`)
  - `kAXMovedNotification` (`windowMoved`)
  - `kAXResizedNotification` (`windowResized`)

This live registry enables instant window lookups, directional focus calculation without expensive process enumeration, and real-time triggers for JavaScript automation scripts.

