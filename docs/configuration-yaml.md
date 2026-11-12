# Configuration File (`~/.mwm.yml`)

MWM (Mac Window Manager, a fork of [Slate](https://github.com/jigish/slate)) reads its configuration from `~/.mwm.yml`. The file is plain data: MWM parses it and registers what it describes, and nothing in it is ever run. **Configure MWM…** (⌘,) in the status menu edits it as a form.

MWM no longer runs JavaScript configurations. On startup it converts `~/.slate`, `~/.slate.js` and `~/.mwm.yml` into `~/.mwm.yml` (see [Migration](#migration)). A legacy `~/.slate` that hasn't been migrated yet still loads, because its format is data too.

---

## 1. Format

```yaml
settings:
  defaultToCurrentScreen: true
  secondsBeforeRepeat: 0.4
  keyboardLayout: "qwerty"

modifiers:
  hyper: "ctrl;alt;cmd"

monitors:
  monitor-samsung: "0"
  monitor-samsung-size: "5120x1440"

positions:
  lefthalf: "move screenOriginX;screenOriginY screenSizeX/2;screenSizeY"

aliases: {}

bindings:
  - group: "Apps"
    key: "c"
    mods: "alt;shift"
    action: "focus 'Google Chrome'"
  - group: "Layout"
    key: "pad4"
    mods: "${hyper}"
    action: "${lefthalf} ${monitor-samsung}"
  - key: "pad7"
    mods: "${hyper}"
    action: "${lefthalf}"
    enabled: false
    note: "thirds"
```

| Section | Contents |
|---|---|
| `settings` | Global configs (see the table in [Classic Configuration](configuration-slate.md)). Values are text, numbers or `true`/`false`; a list is joined with `;`. |
| `modifiers`, `monitors`, `positions`, `aliases` | Named values, used as `${name}` in settings and bindings. The four sections share one namespace and differ only in how the window groups them. |
| `bindings` | A list. `key` and optional `mods` form the hotkey (`key:mods`); `action` is an operation string in the `.slate` format (see the [Operations Reference](operations-reference.md)). Optional: `repeat` (`true`/`false`, defaults to the operation's default), `enabled` (`false` skips the binding), `group` and `note` (shown in the window). |

Aliases follow the legacy `.slate` rules: they can reference other aliases, and an unknown `${name}` is an error. Bindings go through the same parser as `bind` lines in `.slate` (`Binding initWithString:`), so they behave identically.

### Supported YAML

`SlateYAML` reads a strict subset: block mappings and lists, plain, `"double"` and `'single'` quoted values, numbers, `true`/`false`, `null`/`~`, `#` comments, and empty `{}` / `[]`. Anchors, aliases (`&`, `*`), tags (`!`), multi-line strings (`|`, `>`), inline collections (`[a, b]`, `{a: 1}`), tabs for indentation and duplicate keys are errors that name the line, so a file never loads differently from how it reads. Quote a value that starts with a special character or contains `: ` or ` #`.

## 2. The configuration window

The window is a form with a sidebar of sections: General (settings), Modifiers, Monitors, Positions, Other aliases, and bindings grouped as Apps, Layout bindings, Window actions and Features. In a bindings section, click a **Shortcut** to record a new one: press the keys (modifiers show up as you hold them), Esc cancels. A combination that matches a named modifier group is saved as `${name}` (for example `${hyper}`). Shortcuts used by more than one enabled binding are flagged. Right-click a shortcut and choose **Edit as Text…** for keys that can't be recorded.

The bottom bar shows `{saved?} {file} … {valid?} … {Apply} {Close}`.

- **Saving as you go.** Every change is validated (`SlateConfigValidator`) and, if it has no errors, written right away. Warnings don't block saving. Changes with errors show **Not saved**, and the file keeps its last valid version. The first save of a session copies the previous file to `~/.mwm.yml.bak`. Writes are atomic and go through a symlinked `~/.mwm.yml` to its target.
- **Hand edits.** Opening the window doesn't rewrite the file, so comments and layout are kept until something changes in the window, which then writes the canonical layout. If the file changes on disk while the window is open, the window reloads it when it comes to the front (or asks, if it has unsaved changes with errors).
- **Validity.** The status lists errors (YAML problems, unknown aliases, bindings Slate's parser rejects) and warnings (unknown settings, keys bound twice). Choosing one selects the binding or entry it's about. Validation never registers keys or runs operations or shell commands.
- **Unreadable file.** If `~/.mwm.yml` isn't valid YAML in the supported subset, the window shows the error with **Open in Text Editor** and **Reload**.
- **Apply** saves, closes the window and restarts Slate so it loads the file. With errors, it refuses and offers to show the first one. If the file doesn't exist yet, Apply creates it from the defaults shown.

## 3. Migration

On startup, `SlateLegacyMigration` converts the older files into `~/.mwm.yml`:

- **`~/.slate.yml`** (the name this file had before the app was renamed) is read as is and merged in.
- **`~/.slate`**: `config`, `alias` and `bind` lines become settings, aliases and bindings. Each alias is sorted into `modifiers`, `monitors`, `positions` or `aliases` by its value, and `${…}` references are kept as written. Commented-out `bind` lines become bindings with `enabled: false`. A binding's `group` comes from the nearest `# HEADER` comment with a `# ----` underline, and its `note` from comments directly above it. `layout`, `default` and `source` lines, per-app configs and redefined aliases can't be represented; they're listed in the migration alert.
- **`~/.slate.js`** written by the earlier configuration window (a `config` object passed to `slate.applyConfig`) is evaluated once in a bare `JSContext` with no Slate API, files or shell, and its config is converted. Custom code after its marker isn't carried over. Any other JavaScript can't be converted: the file is renamed to `~/.slate.js.unused-<timestamp>` and an alert explains it.
- Precedence matches the old load order: `~/.slate`, then `~/.slate.js`, then `~/.slate.yml`, then an existing `~/.mwm.yml`, with later files winning where they set the same thing. If `~/.mwm.yml` already exists, MWM asks whether to merge, postpone, or stop using the old files.
- Converted files are renamed to `<file>.migrated-<timestamp>` (a symlink itself is renamed, not its target). If the result wouldn't load (for example, a binding uses an undefined alias), nothing is changed.
