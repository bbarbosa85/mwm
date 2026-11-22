# Configuration format v2

Goal: one object per thing, plain names for references, real lists, and no meaning hidden in key
names or in strings that have to be parsed again to be shown. The window-management engine does
not change: the loader turns a v2 file into the same resolved settings and action strings it reads
today.

## Overview

```yaml
version: 2

settings:
  launchAtLogin: true
  checkDefaultsOnLoad: true
  windowHintsFontSize: 14

modifiers:
  hyper: [ctrl, alt, cmd]
  shyper: [shift, ctrl, alt, cmd]

monitors:
  monitor-samsung:
    display: Samsung Odyssey 5120x1440     # which screen, by its model (see below)
    size: 5120x1440                        # optional; used by slots drawn for this screen
  monitor-laptop: {display: built-in}
  monitor-old: {screen: "1"}               # an older numeric reference

slots:
  lefthalf: {x: 0%, y: 0%, width: 50%, height: 100%}
  floating: {formula: "move windowTopLeftX;windowTopLeftY screenSizeX/3;screenSizeY/2"}

aliases:                                   # anything else, used as ${name} in free text
  full: ${lefthalf}

bindings:
  - key: pad8
    mods: hyper                            # a modifier group name, or a list: [ctrl, alt]
    group: Layout
    note: Top half
    action: {type: move, slot: lefthalf, screen: monitor-samsung}
  - key: c
    mods: [alt, shift]
    action: {type: focus-app, app: Google Chrome}
  - key: h
    mods: shyper
    action: {type: hint, letters: ASDFJKL}
    enabled: false
    repeat: false
```

## Rules

1. **Objects for things with several facts.** A monitor is `{display, size}`; a position is
   `{x, y, width, height}`; an action is `{type, …}`. No `monitor-x-size` siblings.
2. **Plain names for references.** `mods: hyper`, `slot: lefthalf`, `screen: samsung`. `${name}`
   remains only inside free text (`aliases` values, `type: custom`, `formula`).
3. **Real lists.** `[ctrl, alt, cmd]`, not `ctrl;alt;cmd`. Settings that were `;`-joined lists
   become lists.
4. **Names are one namespace per section**, and a reference says which section it means by the
   field it is in (`slot:` looks in `positions`, `screen:` in `monitors`, `mods:` in `modifiers`).
5. **Unknown or hand-written things survive.** A position the window can't draw keeps its
   `formula:`; an action it doesn't know stays `{type: custom, text: "chain ..."}`.

## Action objects

| `type` | Fields | Today's string |
|---|---|---|
| `move` | `slot`, optional `screen` | `${slot} ${screen}` |
| `focus-app` | `app` | `focus 'App'` |
| `focus` | `direction`: left, right, up, down, behind | `focus left` |
| `throw` | `screen` (name, `next`, `previous`, number), optional `style` | `throw next resize` |
| `nudge` / `resize` | `x`, `y` | `nudge +10% +0` |
| `push` | `direction`, optional `options` | `push left bar-resize:screenSizeX/2` |
| `hint` | optional `letters` | `hint ASDF` |
| `grid` | optional `arguments` | `grid padding:5 0:6,2` |
| `save-snapshot` | `name`, optional `keep` (true keeps it after restarts) | `snapshot work save-to-disk` |
| `restore-snapshot` | `name` | `activate-snapshot work` |
| `switch`, `relaunch` | none | `switch`, `relaunch` |
| `custom` | `text` | the text as written |

A bare string (`action: relaunch`) is accepted for actions with no fields.

## Monitors: `display`, `screen`, `size`

- `display` is a display role, unchanged in meaning: `built-in`, `Samsung Odyssey 5120x1440`,
  `Samsung Odyssey 5120x1440 #2` (identical displays numbered left to right). A display that isn't
  connected resolves to "the current screen", as now.
- `screen` is an older reference, for files written by hand: `"0"`, `ordered:1`, `next`.
  Use one of `display` and `screen`, not both.
- `size` is the screen's size (`5120x1440`), for slots drawn for it. A monitor with only a size is
  just that size.

Monitor names are kept as they were (`monitor-samsung`): they share a namespace with slots and
aliases, and renaming them would change what `${monitor-samsung}` means in free text.

## Loading and writing

- **Read:** `version: 2` files load with the v2 reader; files without `version` (or `version: 1`)
  load with the original reader, so nothing breaks.
- **Migrate on launch:** at launch, if `~/.mwm.yml` is v1, MWM converts it, keeps the old file as
  `~/.mwm.yml.v1-<timestamp>`, writes v2 and shows one alert. The new text is read back and
  compared with the old document before anything is replaced; if it isn't identical, the file is
  left as it is and the problem is logged.
- **Write:** the window always writes v2. A slot is written as percents only when reading them back
  gives the very same formula, and an action is written as fields only when that reads back as the
  same text; anything else keeps its own text (`formula:` and `type: custom`), so saving never
  changes what a hand-written entry means.
- **In memory:** the document keeps its model (named entries and action strings), so the window
  and the engine don't change; `MWMConfigFormat` translates between that model and the file.
  A monitor object is held as the pair (`name`, `name-size`) the Displays page uses.

## Decisions

- The strict YAML reader now accepts one-line lists and mappings (`[a, b]`, `{x: 1, y: [2]}`),
  with no anchors, tags or multi-line brackets.
- The section is called `slots`, like the window.
- Percents are text (`50%`), up to six decimals (`33.333333%`).
- Settings keep their flat `name: value` form, and a list written there is still joined with `;`.
- Per-app settings and layouts (`.slate` `layout`, `default`, `source`) are not representable and
  stay out of scope.
