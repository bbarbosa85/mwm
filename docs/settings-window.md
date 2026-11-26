# The Settings window

Open it with **Settings…** (⌘,) in the menu bar. It edits the profile you pick, saves as you go, and restarts MWM when you press **Apply and Restart**. The window is always 1080 pt wide and only changes in height (at least 520 pt); every page is laid out for that width, so a page never changes it. The profile files it writes are described in [Profiles](configuration-yaml.md).

## The sidebar

| Group | Pages | What belongs there |
|---|---|---|
| **Keyboard** | Modifiers, Bindings | Your key groups (like hyper) and every shortcut |
| **Screens** | Displays, Slots | Your screens by name, and named areas of a screen |
| **Options** | General, Advanced, Other aliases | Settings, and any other named value |
| **Other** | Snapshots, Backup, Profiles | Things that are not part of a profile: every profile uses them |

Modifiers, Bindings, Displays, Slots and the pages under Options are saved in the profile you are editing. A number on a page is how many entries it holds (General and Advanced show none).

## The bottom bar

From left to right:

- **The profile button.** It names the profile being edited. Its menu lists every profile (a check on the one being edited, "running" on the one MWM is using) and **Manage profiles…**. When the profile being edited is not the running one, a **not applied** chip says so: MWM switches to it only when you press **Apply and Restart**. Closing the window with an unapplied choice asks first.
- **The saved state.** *Saved* when the file matches the form. Hover it to see the file.
- **Whether it is valid**, in the middle: errors and warnings, each one clickable to go to the entry it is about.
- **Apply and Restart**, **Save** (⌘S) and **Close** (⌘W). Changes are written as soon as they are valid, so Save only matters for a change that had errors; Apply and Restart saves, makes the chosen profile the running one and restarts MWM.

A page that opens another (a shortcut or a slot being edited) hides the header and bottom bar and has its own bar with **Save** and **Cancel**.

## Bindings

**Map | List** switches the view.

- **Map.** Groups (your modifier sets, and "Custom" for other combinations) are on the left, with **Manage** to open the Modifiers page. The keyboard is colored by what each key does; click a key to see it. **Key colors** under the keyboard explains the colors (move to slot, windows and apps, features, conflict, reserved by macOS, selected group); dashed keys are modifiers. Under it, a card shows *Press* (the keys) and *To* (what it does, with a preview for a slot), with **Edit**, **Remove**, **Add Shortcut** for a free key, a conflict note when two shortcuts share keys, and **New Shortcut**, which is always there.
- **List.** A searchable list with filters by group and action, and a **conflicts** button when keys are used twice.

### The shortcut page

- **Keys** (a card of its own, first): the keys, with **Record** (press them, Esc cancels) and **Pick on map**. A group that matches is saved as `${name}`.
- **Action.** Four cards for the most common actions, each with an icon and a line saying what it does: **Focus app**, **Move to slot**, **Throw to screen** and **Push**. **More actions** opens the rest as a list: Focus window, Resize, Nudge, Save snapshot, Restore snapshot, Window hints, Grid, Switch windows, Relaunch and **Advanced…** (the action as text). A shortcut that uses one of those shows its own card too.
- **The settings of the action** (a second card), with inputs at the right of each row:
  - *Focus app*: an installed app from the list, or type any name or command.
  - *Move to slot*: a search box and a filter (All slots, Presets, Custom, and **Manage slots…**) over the slots, each with a picture, and **On screen**.
  - *Throw to screen*: **To screen**, then **Window size** as three cards: *Fill the screen* (`resize`), *Keep its size* (`noresize`) or *Custom size* (`resize:<width>;<height>`, with fields for the two expressions).
  - *Push*: the direction, then **Style** as four cards: *Keep its size* (the default), *Centered*, *Full bar* and *Set thickness*, which adds the thickness with its unit (%, px or 1 of N). Then the screen, and the result as a small picture with what it writes.
- **Screens.** Every screen list offers the screens you named on the Displays page and every connected display. A display with no name yet is marked *new*, and gets a name (the Displays page's suggestion) when the shortcut is saved. **Manage displays…** opens the Displays page (asking first if an existing shortcut has unsaved changes).

## Slots

The gallery shows presets and your slots as cards, with a search box. A slot opens in an editor:

- **Name** and, for a new slot, **Mode**: *Simple* (fields) or *Advanced* (a formula).
- **The canvas** shows the slot on a screen. Drag it to move it and drag a handle to resize it; hold **⇧** to keep its proportions and **⌥** to move or resize off the grid. **Preview on** picks the screen shown (your connected displays, then common shapes like 16:9 and 21:9), and **Grid** (Off, 2, 3, 4, 6, 8, 12) sets the lines the slot snaps to.
- **Position, Size and Margins** are blocks with a row for each value: X and Y (with *Center across* and *Center down* switches), Width and Height (in **%** or **px**), and margins in pixels for each edge. Dragging is off while pixels, centering or margins are used.
- In **Advanced** mode, **Formula** (with a help button for the names you can use), **On this screen** (the result in pixels) and **Checks** replace the fields.
- The slot's state ("Name is free · Area is new") is shown in the bottom bar, left of Save.

## Displays

Detects the connected screens and names them (`built-in`, `Samsung Odyssey 5120x1440`, with `#2` for identical ones). The names are what shortcuts use for *On screen* and *To screen*.

## Options

**General** holds the everyday settings (startup, windows, window hints, keyboard layout, the file's location); **Advanced** lists every other setting with its default; **Other aliases** holds any other named value used as `${name}`.

## Snapshots, Backup and Profiles

- **Snapshots** saves where every window is and restores it. See [Configuration](configuration-yaml.md#snapshots).
- **Backup** syncs profiles and snapshots with a private GitHub gist (needs a token).
- **Profiles** lists them as cards. **Add profile** asks where it comes from (the running one, a copy of any profile, or a file), then its name with a short summary of what it holds. A card can rename, duplicate, delete, or **Use** a profile (edit it now; it runs after Apply and Restart).

## The design system

The window is built from shared parts in `MWMTheme` (colors, spacing, type, radii) and `MWMComponents` (cards, list cards, name fields, option cards, save bar, chips). Hold **⌥** on **Settings…** in the menu bar to open **Design System…**, which shows them all.
