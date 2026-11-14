# Settings panel + user config — design

## Why
Change the bar layout and common options from inside the shell instead of hand-editing
the tracked `settings.json`. Personal settings must not show up as git diffs.

## Goals
- Tracked defaults in the repo; personal overrides in an untracked user file.
- A settings panel that edits the user file: reorder modules, move them between pills,
  hide/show them, plus a handful of common options.
- Hot reload keeps working for both files (hand edits included).

## Non-goals
- Moving the bar to bottom/left/right (later).
- A UI for every key in the settings file. Rarely touched options stay hand-edited.

## Anti-goals
- Panel saves that rewrite the whole config or copy all defaults into the user file
  (defaults added later would never reach the user).
- Any module code change: modules keep reading `Config.*` as today.

## Approaches (picked: A)
- **A. Defaults + override file, deep-merged.** Repo `settings.default.json` (tracked) +
  `~/.config/myshell/settings.json` (overrides only). Objects merge per key, arrays and
  scalars replace. New defaults flow through; user file stays small. *Picked.*
- B. Same, but override file git-ignored inside the repo. Rejected: tied to the checkout.
- C. Full copy on first save. Rejected: defaults drift, user file goes stale.

## Design

### Config
- `git mv settings.json settings.default.json` (content unchanged).
- `Config.qml`: two `FileView`s (defaults via `Quickshell.shellPath`, user at
  `$XDG_CONFIG_HOME/myshell/settings.json`, default `~/.config/myshell/settings.json`),
  both `watchChanges`. Parse text with `JSON.parse` (no JsonAdapter), deep-merge into a
  `merged` object; each existing `Config.<section>` property becomes
  `merged.<section> ?? {}`. A missing/empty user file = no overrides; a broken one logs a
  warning and is ignored (defaults still load).
- Write API (used only by the settings panel):
  - `Config.set(path, value)` — e.g. `set("bar.left", [...])`. If the value deep-equals
    the default at that path, the key is removed from the overrides instead (and empty
    parent objects pruned), so the user file holds only real differences.
  - `Config.reset(path)` — remove an override.
  - Writes the user file with `JSON.stringify(overrides, null, 2)` via `FileView.setText`,
    creating `~/.config/myshell/` if needed (`mkdir -p` through `Process`).
- `Config.defaults` / `Config.overrides` exposed read-only so the panel can show
  "changed" markers and per-section Reset.

### Settings panel (`modules/settings/SettingsPanel.qml`, panel id `settings`)
Opened by `panels toggle settings` (placement `fromIpc: "center"`), and from a gear
button in the dashboard (the center panel). From the gear it swaps in place like any
other panel switch, opening at the center pill's spot. Sections, top to bottom:

```
 Bar layout                                     [Reset]
  Left            Center          Right          Hidden
  session  ↑↓→    clock   ←↑↓→    tray    ←↑↓    (modules in no pill)
  workspaces ...  timers  ...     network ...    keyboard  [show]
  ...  each row also has [hide]
 Panel spot per pill:  left [edge-left ▾]  center [pill ▾]  right [edge-right ▾]
 Dashboard cards      Left column / Right column / Hidden (same list editor)
 General
  Palette [default ▾]   Clock format [HH:mm]   Persistent workspaces [- 6 +]
  Network speed in bar [on/off]   Session dry run [on/off]
```

- Reordering uses arrow buttons (↑↓ within a column, ←→ to the neighbouring pill), not
  drag and drop: reliable to click, and no input tools exist to test drag here.
- Hiding removes the id from its pill list; "Hidden" lists `Registry.modules` keys that
  are in no pill. Showing appends it to the right pill (or the one it was hidden from
  during this session).
- Dashboard card ids come from the dashboard's existing card map.
- Each change calls `Config.set` immediately (no Save button); the bar updates live via
  hot reload of the merged config.
- Reusable list editor lives in the settings module folder; theme tokens only.

### Docs
CLAUDE.md: describe `settings.default.json` + user file, `Config.set/reset`, the
`settings` panel; replace references to the tracked `settings.json` as the place for
personal edits.

## Left to the builder
Exact widget styling, how the dropdowns look (cycle button vs. popup list), the dashboard
card id source, and file-write error handling details.
