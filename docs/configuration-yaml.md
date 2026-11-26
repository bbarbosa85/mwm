# Profiles (`~/.mwm/*.mwm.yaml`)

MWM (Mac Window Manager, a fork of [Slate](https://github.com/jigish/slate)) reads its configuration from a file in the `~/.mwm` folder. Each profile is one file, `<name>.mwm.yaml` (a `.mwm.yml` file is listed too), and exactly one is **active**: its name is kept in `~/.mwm/active`, and MWM loads that file. The files are plain data: MWM parses them and registers what they describe, and nothing in them is ever run. **Settings…** (⌘,) in the status menu edits the active one as a form.

**Several profiles.** `MWMProfiles` lists, creates, duplicates, renames and deletes them (a deleted one goes to the Trash; the active and the last one can't be deleted). The button at the left of the Settings window's bottom bar (`ConfigurationProfileBar`) shows the profile being edited and chooses another; the **Profiles** menu in the menu bar opens Settings on one. Choosing a profile only changes what the window edits: it becomes the active one (`~/.mwm/active`) when **Apply and Restart** is pressed, and closing the window with an unapplied choice asks first. Snapshots are shared by every profile.

**Backup is a sync.** `MWMSync` makes `~/.mwm` (and the snapshots) match one private GitHub gist: it sends what changed here, receives what changed there, and the newer file wins when both changed (the other is kept as `<file>.bak`). The gist holds `<name>.mwm.yaml`, `snapshots.json` and `mwm-sync.json` (when each file was last sent); `~/.mwm/.sync.json` records what both sides looked like at the last sync, so a deletion on one side is flagged instead of guessed. Nothing is deleted by a sync: the person chooses to clear or keep. `MWMSyncPlan` is the pure rule set; `MWMGist` is the GitHub API.

MWM no longer runs JavaScript configurations. The first time it opens with the `~/.mwm` folder, an existing `~/.mwm.yml` moves into it and `~/.slate`, `~/.slate.js` and `~/.slate.yml` are converted and imported (see [Migration](#migration)). The Slate files are only read, never changed, and a `~/.slate` is never loaded directly.

---

## 1. Format

The file has a `version: 2` layout: one object per monitor, slot and action, plain names for references, and real lists. The full description (with the reasons and the old layout) is in [Configuration format v2](configuration-format-v2.md). Files in the original layout (no `version`) still load, and MWM rewrites them once at startup, keeping the old file as `~/.mwm.yml.v1-<timestamp>`.

```yaml
version: 2

settings:
  defaultToCurrentScreen: true
  secondsBeforeRepeat: 0.4
  keyboardLayout: qwerty

modifiers:
  hyper: [ctrl, alt, cmd]

monitors:
  monitor-samsung: {display: Samsung Odyssey 5120x1440, size: 5120x1440}
  monitor-laptop: {display: built-in}

slots:
  lefthalf: {x: 0%, y: 0%, width: 50%, height: 100%}

aliases: {}

bindings:
  - group: Apps
    key: c
    mods: [alt, shift]
    action: {type: focus-app, app: Google Chrome}
  - group: Layout
    key: pad4
    mods: hyper
    action: {type: move, slot: lefthalf, screen: monitor-samsung}
  - key: pad7
    mods: hyper
    action: {type: move, slot: lefthalf}
    enabled: false
    note: thirds
```

| Section | Contents |
|---|---|
| `version` | `2`. A file without it is read as the original layout. |
| `settings` | Global configs (see the table in [Classic Configuration](configuration-slate.md)). Values are text, numbers or `true`/`false`; a list is joined with `;`. |
| `modifiers` | Named modifier groups: `hyper: [ctrl, alt, cmd]`. Used by name in `mods:`. |
| `monitors` | One object per monitor: `display` (the screen's model, like `built-in` or `Samsung Odyssey 5120x1440`, with `#2` for identical ones), or `screen` (an older reference like `0`, `ordered:1`, `next`), and an optional `size` for slots drawn for that screen. |
| `slots` | Named window areas: `{x, y, width, height}` in percent of the screen, or `{formula: "move ..."}` for an area that depends on the window or another screen. |
| `aliases` | Any other named text, used as `${name}`. |
| `bindings` | A list. `key` and optional `mods` (a group name, or a list like `[alt, shift]`) form the hotkey; `action` is an object with a `type`, or plain text for an action with no fields. Optional: `repeat`, `enabled` (`false` skips it), `group` and `note` (shown in the window). |

Action types: `move` (`slot`, `screen`), `focus-app` (`app`), `focus` (`direction`), `throw` (`screen`, `style`), `nudge` and `resize` (`x`, `y`), `push` (`direction`, `options`), `hint` (`letters`), `grid` (`arguments`), `switch`, `relaunch`, `save-snapshot` (`name`, `keep`) and `restore-snapshot` (`name`), and `custom` (`text`, an operation as in the [Operations Reference](operations-reference.md)). An action the window can't write as fields keeps its text as `custom`.

Names of modifiers, monitors, slots and aliases share one namespace. In free text (`aliases` values, `custom` actions, `formula`) a name is written `${name}`; fields that take a name (`mods`, `slot`, `screen`) take it plain. Aliases follow the legacy `.slate` rules: they can reference other aliases, and an unknown `${name}` is an error. Actions go through the same parser as `bind` lines in `.slate` (`Binding initWithString:`), so they behave identically.

### Snapshots

The Snapshots page saves where every open window is (with the screens at the time), shows each one as a picture with the app icons, and restores, renames or deletes it. **Keep after restart** writes a snapshot to disk (`save-to-disk`); without it a snapshot is forgotten when MWM quits. Snapshots live in MWM's support folder, not in `~/.mwm.yml`. A shortcut can save or restore one with the `save-snapshot` and `restore-snapshot` actions.

### Supported YAML

`MWMYAML` reads a strict subset: block mappings and lists, one-line lists and mappings (`[a, b]`, `{a: 1, b: [c]}`), plain, `"double"` and `'single'` quoted values, numbers, `true`/`false`, `null`/`~`, `#` comments, and empty `{}` / `[]`. Anchors, aliases (`&`, `*`), tags (`!`), multi-line strings (`|`, `>`), lists and mappings spread over several lines inside brackets, tabs for indentation and duplicate keys are errors that name the line, so a file never loads differently from how it reads. Quote a value that starts with a special character or contains `: ` or ` #`.

## 2. The Settings window

**Settings…** opens a form for the profile you pick; the pages, the shortcut and slot editors and the bottom bar are described in [The Settings window](settings-window.md). What matters for the file:

- **Saving as you go.** Every change is validated (`MWMConfigValidator`) and, if it has no errors, written right away. Warnings don't block saving. Changes with errors show **Not saved**, and the file keeps its last valid version. The first save of a session copies the previous file to `<file>.bak`. Writes are atomic and go through a symlinked file to its target.
- **Hand edits.** Opening the window doesn't rewrite the file, so comments and layout are kept until something changes in the window, which then writes the canonical layout. If the file changes on disk while the window is open, the window reloads it when it comes to the front (or asks, if it has unsaved changes with errors).
- **Validity.** The bottom bar lists errors (YAML problems, unknown aliases, bindings the parser rejects) and warnings (unknown settings, keys bound twice). Choosing one selects the entry it's about. Validation never registers keys or runs operations or shell commands.
- **Unreadable file.** If the file isn't valid YAML in the supported subset, the window shows the error with **Open in Text Editor** and **Reload**.
- **Apply and Restart** saves, makes the profile being edited the active one, closes the window and restarts MWM so it loads the file. With errors, it refuses and offers to show the first one. If the file doesn't exist yet, it creates it (and `~/.mwm`) from the defaults.
- **Screens in shortcuts.** A shortcut can point at a connected display that has no name yet. Saving the shortcut adds that display to `monitors` under the name the Displays page would suggest.

## 3. Migration

The first time MWM opens while `~/.mwm` doesn't exist, `MWMLegacyMigration` sets the folder up:

- **`~/.mwm.yml`** (the one file earlier versions used) moves to `~/.mwm/default.mwm.yaml`. A symlink moves as a symlink.
- **Slate files** are read, never renamed, moved or changed, and become the profile `default` (or `slate-import` next to a moved `~/.mwm.yml`). They are loaded only this once: MWM never loads `~/.slate` itself.
  - **`~/.slate.yml`** (the name this file had before the app was renamed) is read as is.
  - **`~/.slate`**: `config`, `alias` and `bind` lines become settings, aliases and bindings. Each alias is sorted into `modifiers`, `monitors`, `positions` or `aliases` by its value, and `${…}` references are kept as written. Commented-out `bind` lines become bindings with `enabled: false`. A binding's `group` comes from the nearest `# HEADER` comment with a `# ----` underline, and its `note` from the comment directly above it. Lines that couldn't be converted are listed as warnings.
  - **`~/.slate.js`** written by the earlier configuration window (a `config` object passed to `slate.applyConfig`) is evaluated once in a bare `JSContext` with no Slate API, files or shell, and its config is converted. Custom code after its marker isn't carried over. Any other JavaScript can't be converted and is reported in the alert; the file stays where it is, unused.
  - Precedence matches the old load order: `~/.slate`, then `~/.slate.js`, then `~/.slate.yml`, with later files winning where they set the same thing. If the result wouldn't load (for example, a binding uses an undefined alias), nothing is imported, the alert says why, and the Slate files are still untouched.
- One alert says what moved and what was imported. When there is nothing to move or import, no folder is made until the first configuration is saved.

### Actions

A shortcut's action is edited as cards and fields (see [The Settings window](settings-window.md#the-shortcut-page)): **Focus app**, **Move to slot**, **Throw to screen** and **Push** first, then **Focus window**, **Resize**, **Nudge**, **Save snapshot**, **Restore snapshot**, **Window hints**, **Grid**, **Switch windows**, **Relaunch** and **Advanced…**, which edits the plain text. Any action the window doesn't recognize (`chain`, `shell`, ...) stays there unchanged.

A `throw` action's `style` is `resize` (fill the screen), `noresize` (keep the window's size, also what an empty style means) or `resize:<width>;<height>` (a size written as expressions, such as `resize:screenSizeX/2;screenSizeY`).
