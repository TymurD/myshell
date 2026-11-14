# Settings Panel + User Config Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Tracked defaults + untracked user overrides, deep-merged, and a settings panel that edits the overrides.

**Architecture:** Pure merge/path helpers in `config/merge.js` (unit-tested with node). `Config.qml` reads both files as text, merges, exposes the same `Config.<section>` properties plus `set/reset`. A `settings` panel edits through `Config.set`.

**Tech Stack:** Quickshell 0.3 QML, Qt 6, node (tests only).

**Spec:** `docs/superpowers/specs/2026-11-14-settings-panel-design.md`

## Global Constraints

- Defaults file: `settings.default.json` (tracked, content = current `settings.json`).
- User file: `$XDG_CONFIG_HOME/myshell/settings.json`, fallback `~/.config/myshell/settings.json`.
- Merge: objects merge per key; arrays and scalars replace.
- `Config.set` stores only values that differ from defaults; equal → key removed, empty parents pruned.
- No module code reads anything but `Config.*`; no hard-coded colors/sizes/durations (Theme/Anim tokens).
- Panel id `settings`, placement `fromIpc: "center"`; gear button in the dashboard header.
- Reordering via arrow buttons, no drag and drop.

## Review Focus

1. User file missing → defaults only, no error spam; first `set` creates the directory and file.
2. User file with invalid JSON → warning logged, defaults still apply, panel edits don't overwrite the broken file (refuse to write while it's unparseable).
3. Hand edit of either file while running → merged config hot-reloads.
4. Setting a list back to exactly the default order → key disappears from the user file.
5. Hiding every module of a pill → pill collapses (existing `visible: modules.length > 0`), and the module shows in Hidden.

---

### Task 1: Merge helpers

**Files:**
- Create: `config/merge.js` (`.pragma library`)
- Test: `tests/merge.test.mjs` (loads `merge.js` text into `node:vm`, strips the pragma line)

**Interfaces:**
- Produces: `deepMerge(base, over) -> object`, `getPath(obj, path: string) -> any`, `withPath(obj, path, value) -> object` (copy), `withoutPath(obj, path) -> object` (copy, prunes empty parents), `deepEqual(a, b) -> bool`, `overridesAfterSet(defaults, overrides, path, value) -> object`. Paths are dot-separated (`"bar.left"`).

- [ ] **Step 1: Write the failing tests** (`node:test` + `assert`):
  - `deepMerge({bar:{left:["a","b"],height:34}}, {bar:{left:["b"]}})` → `{bar:{left:["b"],height:34}}`
  - `deepMerge({a:{b:1}}, {a:{c:2}})` → `{a:{b:1,c:2}}`; `deepMerge(d, {})` deep-equals `d` and does not mutate `d`
  - `getPath({a:{b:2}}, "a.b")` → `2`; missing → `undefined`
  - `withoutPath({bar:{left:[1]}}, "bar.left")` → `{}`
  - `overridesAfterSet({bar:{left:["a","b"]}}, {}, "bar.left", ["b","a"])` → `{bar:{left:["b","a"]}}`
  - `overridesAfterSet({bar:{left:["a","b"]}}, {bar:{left:["b","a"]}}, "bar.left", ["a","b"])` → `{}`
- [ ] **Step 2:** `node --test tests/` → FAIL (file missing)
- [ ] **Step 3:** Implement the functions in `config/merge.js`. Plain objects only (arrays are leaves).
- [ ] **Step 4:** `node --test tests/` → all pass
- [ ] **Step 5:** Commit `config/merge.js tests/merge.test.mjs`

### Task 2: Config reads defaults + user file, writes overrides

**Files:**
- Rename: `settings.json` → `settings.default.json` (`git mv`)
- Modify: `config/Config.qml` (replace JsonAdapter with two FileViews + merge)
- Modify: `core/Ipc.qml` (add `config` target)

**Interfaces:**
- Consumes: Task 1 functions via `import "merge.js" as Merge`.
- Produces on `Config`: every existing readonly section property (same names, now `merged.<x> ?? {}`; `palette: merged.palette ?? "default"`), `readonly property var defaults`, `readonly property var overrides`, `readonly property bool userFileBroken`, `function set(path: string, value: var): void`, `function reset(path: string): void`, `function get(path: string): var`.
- IPC target `config`: `get(path): string` (JSON), `set(path, json: string): void`, `reset(path): void`, `userPath(): string`.

- [ ] **Step 1:** `git mv settings.json settings.default.json`.
- [ ] **Step 2:** Rewrite `Config.qml`: defaults FileView at `Quickshell.shellPath("settings.default.json")`; user FileView at `userPath` (from `Quickshell.env("XDG_CONFIG_HOME")` or `Quickshell.env("HOME") + "/.config"`, + `/myshell/settings.json`), `printErrors: false` for the user file, both `watchChanges` + `onFileChanged: reload()`. Parse with `JSON.parse` in try/catch; empty/missing user file → `{}`; parse error → warn once, `userFileBroken = true`, overrides `{}`. Keep the current JsonAdapter defaults as an in-code `fallback` object merged under the defaults file. `set/reset` compute new overrides with `Merge.overridesAfterSet`/`withoutPath`, refuse while `userFileBroken` (warn), run `mkdir -p <dir>` via a `Process` once, then `userFile.setText(JSON.stringify(o, null, 2) + "\n")`.
- [ ] **Step 3:** Add the `config` IpcHandler to `core/Ipc.qml`.
- [ ] **Step 4: Verify** with an isolated config dir:
  `XDG_CONFIG_HOME=$SCRATCH/cfg qs -p . &` then
  - log shows `Configuration Loaded`, no errors; bar unchanged.
  - `qs -p . ipc call config set bar.right '["tray","network"]'` → `$SCRATCH/cfg/myshell/settings.json` is `{"bar":{"right":["tray","network"]}}`; `ipc call config get bar.left` still returns the default left list.
  - `ipc call config set bar.right '["tray","brightness","network","notifications"]'` → file is `{}`.
  - write `{bad` into the file → warning, `config get bar.left` returns defaults; `config set …` refuses.
  - delete the file → no errors.
- [ ] **Step 5:** Commit.

### Task 3: Card map in Registry

**Files:**
- Modify: `core/Registry.qml` (add `readonly property var cards`, same map as today), `modules/dashboard/CardColumn.qml` (use `Registry.cards`)

- [ ] **Step 1:** Move the map; CardColumn imports `qs.core`.
- [ ] **Step 2: Verify:** `ipc call panels open dashboard` → no "unknown card" warnings in the log, no QML errors.
- [ ] **Step 3:** Commit.

### Task 4: Settings panel

**Files:**
- Create: `modules/settings/SettingsPanel.qml` (PanelSurface, scrollable column of sections), `modules/settings/ListEditor.qml` (columns of ids + Hidden column), `modules/settings/Section.qml` (title + Reset button), `modules/settings/OptionRow.qml` (label + control: cycle button, toggle, stepper, or text field)
- Modify: `core/Registry.qml` (`panels.settings = { url: "settings/SettingsPanel.qml", placement: { fromIpc: "center", keyboard: true } }`), `core/OverlayWindow.qml` (`import qs.modules.settings`), `modules/dashboard/DashboardPanel.qml` (gear icon button in the date column header → `PanelManager.open("settings", PanelManager.source, PanelManager.anchor)`; check `PanelManager.open`'s signature and keep the center pill spot)

**Interfaces:**
- `ListEditor { property var columns: [{ title, path }]; property var allIds: [] }` — reads lists via `Config.get(path)`, Hidden = `allIds` not in any column. Row buttons: ↑ ↓ (within column), ← → (to neighbour column), hide (`×`). Hidden rows: show (appends to the column it was last hidden from, else the last column). Every action writes the changed column(s) with `Config.set`.
- Sections and the config paths they write:
  - Bar layout: `ListEditor` on `bar.left|center|right`, `allIds: Object.keys(Registry.modules)`; Reset → `reset("bar.left")`, `"bar.center"`, `"bar.right"`.
  - Panel spot: three cycle buttons `bar.panelAt.left|center|right` over `["edge-left","pill","edge-right"]`; Reset → `reset("bar.panelAt")`.
  - Dashboard cards: `ListEditor` on `dashboard.left|right`, `allIds: Object.keys(Registry.cards)`.
  - General: palette (cycle over `palettes/*.json` names from a `FolderListModel` or `ls` Process, excluding none), `clock.format` (text field, commit on Enter), `workspaces.persistent` (stepper 1–10), `network.showSpeed` (toggle), `session.dryRun` (toggle).
- Changed values show an accent dot (`Merge.getPath(Config.overrides, path) !== undefined`).
- A banner when `Config.userFileBroken` ("settings.json has a syntax error; fix it to save changes").

- [ ] **Step 1:** Build the files; Theme/Anim tokens only, `IconButton`-style buttons local to the folder (existing pattern).
- [ ] **Step 2: Verify:** shell running with isolated `XDG_CONFIG_HOME`: `ipc call panels open settings` → no QML errors; `ipc call panels open dashboard` → no errors; `ipc call config set bar.left '["session"]'` while the panel is open → no errors (panel re-reads). `grim` screenshot of the open panel looks right.
- [ ] **Step 3:** Ask the user to click through: reorder, move between pills, hide/show, gear button, a toggle. (Clicks can't be automated here.)
- [ ] **Step 4:** Commit.

### Task 5: Docs

**Files:** Modify `CLAUDE.md`, `.gitignore` (nothing needed: user file is outside the repo).

- [ ] **Step 1:** CLAUDE.md: layout block (`settings.default.json`, user file), "Config vs state" (defaults vs overrides, merge rules, `Config.set/reset`), IPC list (`config get|set|reset|userPath`), module contract step 3 (ids go in `settings.default.json`), roadmap entry for the settings panel, and replace other "settings.json" mentions meaning the tracked file.
- [ ] **Step 2:** Commit.
