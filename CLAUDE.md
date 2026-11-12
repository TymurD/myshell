# myshell

A modular [Quickshell](https://quickshell.org) desktop shell for Hyprland. Replaces waybar, mako, fuzzel, hyprlock and polkit-gnome with one QML codebase.

Target: Quickshell **0.3.x**, Hyprland **0.57+ with Lua config** (`~/.config/hypr/hyprland.lua`), Qt 6.

## Run / reload / debug

```bash
mkdir -p ~/.config/quickshell && ln -s ~/projects/myshell ~/.config/quickshell/myshell   # once
qs -c myshell                 # run (or `qs -p .` from the repo)
qs -c myshell log             # tail logs of the running instance
qs -c myshell ipc show        # list IPC targets/functions
qs -c myshell ipc call panels toggle dashboard
qs -c myshell kill
```

- Quickshell hot-reloads on every file save; `settings.json` and palettes are watched too.
- LSP: Quickshell writes `.qmlls.ini` (gitignored) when the file exists. Run `touch .qmlls.ini` once, then `qmlls` works.
- After a change, start the shell and check for a clean log (`Configuration Loaded` with no QML errors). Use `grim` to screenshot if visual verification is needed.

## Dependencies

quickshell, hyprland, JetBrainsMono Nerd Font, playerctl (debug only, MPRIS is native), matugen (palettes, later), wl-clipboard + **cliphist** (clipboard, not installed yet), lm_sensors (temps), NetworkManager.

## Layout

```
shell.qml            ShellRoot: per-screen BarWindow + OverlayWindow, Ipc
settings.json        user settings (tracked): bar layout, panel placement overrides, module options
palettes/*.json      color palettes; Config.palette picks one. generated.json = matugen output (gitignored)
config/Config.qml    singleton, reads settings.json (FileView + JsonAdapter)
theme/Theme.qml      singleton, semantic color/size/font tokens from the active palette
theme/Anim.qml       singleton, animation durations/easings
core/                shell plumbing: Registry, PanelManager, BarWindow, OverlayWindow, Ipc
components/          reusable dumb UI: Pill, BarButton, StyledText, Icon, PanelSurface, PlaceholderPanel
services/            singletons holding state/logic (no UI): Time, KbLayout, Workspaces, Battery, Network,
                     Media, Notifications, Session, Apps, Clipboard, SysStats, Weather, Timers
modules/<id>/        one folder per feature: <Name>Bar.qml, <Name>Panel.qml, optional <Name>Card.qml
scripts/             helper shell scripts (share picker, palette apply/reload, ...)
```

Imports use Quickshell's `qs.` root (`import qs.services`, `import qs.theme`, …). No qmldir files needed. Singletons need `pragma Singleton` + a `Singleton {}` root.

**Module folders must be imported statically somewhere.** Quickshell only scans a folder as a module when a statically loaded file imports it. Panels are loaded by URL through a Loader, so `core/OverlayWindow.qml` imports every panel/card folder (`import qs.modules.<id>`). **When you add a new panel or card folder, add its import there** (bar-module folders whose files use siblings go in `core/BarWindow.qml`, e.g. `qs.modules.tray`), or its sibling files fail with "X is not a type". Global UI modules (lock, polkit, notifications, keyboard OSD) are imported and instantiated in `shell.qml`. Files inside a module folder import their own folder (`import qs.modules.<id>`) to use siblings.

Avoid naming a QML file after a QtQuick type (`Text`, `Calendar`, …): it shadows or fails to resolve. Use `StyledText`, `MonthCalendar`, etc.

**Layering:** `services` (data, no UI) → `components` (generic UI, no data) → `modules` (glue services to components). `core` runs the bar/panel machinery. Modules never talk to each other directly; they share state through services.

## Module contract

Every feature has a **minimal** bar version and an **expanded** panel version.

- `modules/<id>/<Name>Bar.qml`: root is `BarButton`. It gets `moduleId`, `barScreen` and `pill` injected. Clicking opens the panel mapped in `Registry.modules[id].panel`. Use `onLeftClicked`/`onRightClicked` for extra actions, and `hoverHighlight: false` when the item has its own sub-buttons. Hide a module with `shown: false`, **not** `visible`, so the pill collapses around it.
- Bar items must be **informative, not a lone icon**: icon + the useful value (connection name, track title, percent, layout). A bare icon is only OK for pure actions (session/power).
- `modules/<id>/<Name>Panel.qml`: root is `PanelSurface` (or wraps one). Set `implicitWidth`/`implicitHeight`. May declare `property string panelId` (injected).
- `modules/<id>/<Name>Card.qml` (optional): compact variant for dashboard slots.
- All logic, polling, processes and persistence go in `services/<Name>.qml`, never in UI files.

### Adding a module
1. Create `modules/<id>/` with the Bar and/or Panel file.
2. Register it in `core/Registry.qml`: `modules.<id> = { bar, panel }` and/or `panels.<panelId> = { url, placement }`. `url: ""` shows `PlaceholderPanel`.
3. Put the id into `settings.json` → `bar.left|center|right` (order = display order).
4. If it needs data, add `services/<Name>.qml`.
5. If it should be keybindable, it already is: `qs -c myshell ipc call panels toggle <panelId>`.

## Bar

Three pills (left / center / right), each one continuous capsule with no separators between modules. Contents come from `settings.json` `bar.*`. Default:

| left | center | right |
|---|---|---|
| session, workspaces, keyboard, battery | clock, media | tray, network, notifications |

## Panels and placement

- Only one panel is open at a time (`core/PanelManager.qml`: `open/toggle/close(id, source, pill)`). The exception is launcher + clipboard, which open as a pair.
- Panels render in a per-screen fullscreen transparent `OverlayWindow`. Its input mask covers only the visible panel. Click-outside (HyprlandFocusGrab) and Esc close the panel.
- **Opened from the bar, position is decided by the pill, not the button.** Every button in one pill opens its panel in the same spot. Clicking another button while a panel is open swaps to the new panel: it snaps to its own rect and the content fades in. Don't animate geometry between panels; it reads as the panel spawning in the wrong spot and sliding. The spot per pill is in `settings.json` → `bar.panelAt`. Defaults: left → `"edge-left"`, center → `"pill"` (top, centered under the center pill, used by the dashboard), right → `"edge-right"`. Panels always hang from the top, just below the bar.
- Per-panel placement lives in `Registry.panels[id].placement` and can be overridden in `settings.json` → `panels.<id>`:
  - `fromBar` (optional): overrides the pill's spot for this one panel. Avoid it, since it breaks the "same place per pill" rule.
  - `fromIpc`: `"center-top"` (default for keybinds) | `"center"` | `"edge-left"` | `"edge-right"`.
  - `"center"` = vertically centered on screen (launcher, session menu via keybind).
  - `keyboard: true` gives the panel exclusive keyboard focus (launcher, clipboard, lock-style input).
  - `fillHeight: true`: stretch from under the bar down to the bottom gap (notification center).
  - `attach: { to, side }`: open beside another panel (clipboard sits left of the launcher). Opening the attached panel directly opens its host with the attached one focused. `PanelManager.focusId` / `moveFocus("left"|"right")` move keyboard focus between them.
- Animations: a bar-opened panel grows out of its pill (a capsule in pill colour expands into the panel rect, content fades in late) and shrinks back on close. Keybind-opened panels fade/slide. The overlay keeps the last panel loaded while it animates out. Click-outside grab activates only after the open animation, so the opening click doesn't close it.
- Services can react to a panel being open via `PanelManager.openId` (e.g. Network scans only while its panel is open, SysStats polls only while a card is visible).

## Theme & animation rules

- **Never hard-code colors, font sizes, radii or durations in modules.** Use `Theme.*` and `Anim.*`. Add a token if one is missing. Font scale: `fontSizeSmall` 13 · `fontSize` 17 · `fontSizeLarge` 22 · `fontSizeXL` 32 · `fontSizeDisplay` 44 · `fontSizeHuge` 110.
- Palette file = flat JSON of token → `#aarrggbb`/`#rrggbb` (see `palettes/default.json`). Switching = change `palette` in settings.json (later: palette panel + `theme set` IPC).
- Planned matugen flow: wallpaper → `matugen` → `palettes/generated.json` + templates for other apps → `scripts/apply-palette` reloads them.
- Icons: Nerd Font glyphs via `Icon { code: 0xF0150 }`.

## Config vs state

- `settings.json` (repo, tracked): things the user edits by hand.
- Runtime state via `Quickshell.statePath("<name>.json")`, which resolves to `~/.local/state/quickshell/by-shell/<shell-id>/`: `notifications.json` (history, DND, mutes), `timers.json` (timers/alarms, stored as end timestamps), `apps.json` (launcher frequency), `weather.json` (cache). Write it from services only. Every running instance of the same shell shares these files, so run only one real instance.
- Clipboard image thumbnails go to `Quickshell.cachePath("clipboard")`.

## IPC

Target names are lowercase nouns, functions are verbs. `panels` and `keyboard` live in `core/Ipc.qml`; every other target is declared by its own module/service with an `IpcHandler`. Run `qs -c myshell ipc show` for the live list.

- `panels toggle|open <id>`, `panels close`, `panels list`
- `keyboard next`
- `lock lock|preview|closePreview` (use `preview` for testing; it is a plain overlay, not a session lock)
- `polkit preview|cancel|status`
- `session lock|logout|suspend|reboot|shutdown|dryrun <bool>`
- `notifications toggleDnd|clear|mute <app>|unmute <app>|invokeLatest <action>|status`
- `timers start <sec>|startNamed <name> <sec>|cancelAll|toggleStopwatch|next`
- planned: `sharepicker pick <fifo>`, `theme set <palette>`

Singletons that own an IPC target or must run from startup (e.g. `Timers`, for alarms) are touched in `shell.qml`'s `Component.onCompleted`. Singletons are created lazily, so their IpcHandler doesn't exist until something uses them.

## Hyprland integration (Lua config)

`hyprctl dispatch` takes **Lua expressions** with this config (e.g. `hyprctl dispatch 'hl.dsp.focus({ workspace = 3 })'`). In QML, prefer native methods (`HyprlandWorkspace.activate()`). If you must use `Hyprland.dispatch(...)`, pass Lua. `hyprctl switchxkblayout` is a normal command, not a dispatcher.

Snippets for `hyprland.lua`:

Switching over (all of these at once; the QS modules can't register while the old daemons run):
remove the `waybar`, `mako` and `/usr/lib/polkit-gnome/...` execs, then add:

```lua
hl.exec_cmd("qs -c myshell")                       -- bar, notifications, polkit agent, lock, launcher
hl.exec_cmd("wl-paste --watch cliphist store")     -- clipboard history
local qs = "qs -c myshell ipc call "
hl.bind(mainMod .. " + D", hl.dsp.exec_cmd(qs .. "panels toggle launcher"))
hl.bind(mainMod .. " + BackSpace", hl.dsp.exec_cmd(qs .. "lock lock"))
hl.bind(mainMod .. " + V", hl.dsp.exec_cmd(qs .. "panels toggle clipboard"))
hl.bind(mainMod .. " + N", hl.dsp.exec_cmd(qs .. "panels toggle notifications"))
hl.bind(mainMod .. " + C", hl.dsp.exec_cmd(qs .. "panels toggle dashboard"))
hl.bind(mainMod .. " + Escape", hl.dsp.exec_cmd(qs .. "panels toggle session"))
-- misc: allow_session_lock_restore = true  (MUST be set before using the QS lock screen)
```

Logout uses `hyprctl dispatch 'hl.dsp.exit()'` (checked against `/usr/share/hypr/stubs/hl.meta.lua`, which documents the Lua API).

Edit `~/.config/hypr/hyprland.lua` only when the user asks. Never remove waybar/mako/hyprlock/polkit-gnome execs until the replacing module works.

## Notes / answers

- **Lock screen:** yes. `WlSessionLock` + `PamContext` (Quickshell.Services.Pam). Set Hyprland `misc.allow_session_lock_restore = true` so a crashed qs can be restarted (`qs -c myshell`) instead of leaving a dead red lock screen. Keep hyprlock as a fallback bind until it's proven.
- **Polkit:** yes. `Quickshell.Services.Polkit` → `PolkitAgent` and our own dialog. Remove polkit-gnome when it ships, since only one agent can register.
- **Screenshare picker:** yes, via xdg-desktop-portal-hyprland. In `~/.config/hypr/xdph.conf` set `screencopy { custom_picker_binary = <repo>/scripts/share-picker }`. The script creates a FIFO and calls `ipc call sharepicker pick <fifo>`. The QML picker writes the selection (`[SELECTION]/screen:<name>` or `window:<handle>`, so check the xdph source for the exact format) into the FIFO, and the script prints it to stdout.
- **Notifications:** only one `NotificationServer` can own the D-Bus name, so kill mako first. A QS instance that fails to register retries whenever the name frees up.
- **Polkit:** while polkit-gnome runs, Quickshell logs "An authentication agent already exists" once. That's expected.
- **Session:** set `session.dryRun: true` in settings.json while developing the session panel; commands are then only logged.
- **dGPU:** `nvidia-smi` wakes the NVIDIA card. SysStats only queries it when `/sys/bus/pci/devices/<dgpuPci>/power/runtime_status` is `active`, and at most every `sysstats.gpuInterval`.
- **Battery / TLP:** profiles are switched through `PowerProfiles` (Quickshell.Services.UPower). tlp-pd owns `net.hadess.PowerProfiles`, so Saver/Balanced/Performance map onto TLP profiles with no root or sudo. Battery data comes from `UPower.displayDevice`. Logic is in `services/Battery.qml`.
- **Volume:** not controlled. The media panel shows default sink volume read-only (Services.Pipewire).
- **Weather:** Open-Meteo (no API key), coords in `settings.json` → `weather.latitude/longitude` (unset, so the cards ask for them). Never geolocate automatically.
- **Clipboard:** needs `cliphist` (not installed yet) and the `wl-paste --watch cliphist store` exec.

## Gotchas

- Layer-shell keyboard focus: default `None`. Use `Exclusive` only while a typing panel is open, or you steal input from apps.
- Long-running/blocking work → `Process` / `FileView` (async). Never busy-loop in JS; poll with `Timer`.
- `Process` + `StdioCollector`/`SplitParser` for CLI tools (cliphist, nmcli fallback, sensors). Use `Quickshell.execDetached` for fire-and-forget.
- `Hyprland.workspaces` / `toplevels` are ObjectModels: use `.values`.
- `UPower.displayDevice.percentage` is 0–1.
- Waybar running at the same time pushes our bar down, so panel offsets look wrong until waybar is removed.
- No input injection tools (wtype/ydotool) are installed, so automated tests can drive the shell only through IPC. Typing, clicks and hover have to be checked by the user.
- When testing, address your instance with `qs ipc --pid <pid>` or `qs -p <repo> ipc`. Don't `pkill -f "qs -p ."` from a shell whose own command line contains that string.
- Hot reload can miss edits to files only reached through a panel Loader. If a change doesn't show up, `touch shell.qml`.
- A reusable widget that takes `focus: true` from its caller and has its own focused child (e.g. a text input) must have a `FocusScope` root. Otherwise the two compete in one scope and keys go to the wrapper.
- A QML file can't instantiate its own type (even inside a Component). For recursive UI (tray submenus), load it by URL: `Loader.setSource(Qt.resolvedUrl("Self.qml"), props)`.
- MPRIS `position` isn't notified: `services/Media.qml` calls `positionChanged()` on a 1 s timer while playing.

## Roadmap

- [x] **P1 Skeleton**: config/theme/palette, Registry, PanelManager, OverlayWindow, 3-pill bar, IPC
- [x] Per-pill panel placement, snap + fade swap, drop-down open animation, attached panels
- [x] Bar items: session, workspaces, keyboard, battery, clock (+ running timer), media (+ progress underline), tray, network, notifications (unread count / DND)
- [x] Battery panel with TLP power profiles
- [x] Lock screen (WlSessionLock + PAM, blurred screencopy), polkit agent dialog, session menu (two-click confirm)
- [x] Notifications: server, toasts, center grouped by app, DND, per-app mute, persisted history
- [x] Launcher (fuzzy + frequency) + clipboard history (cliphist, image thumbnails) attached on its left; keyboard-layout OSD
- [x] Media panel (art, seek, controls, shuffle/loop, player switcher, read-only volume); network panel (wifi list, connect/password, forget, wired, IP, rates)
- [x] Dashboard (calendar center, configurable card columns), SysStats cards (CPU/GPU/RAM/temps), weather + forecast, timers/stopwatch/alarms
- [ ] **Switch-over**: install cliphist, set allow_session_lock_restore, swap waybar/mako/polkit-gnome/fuzzel/hyprlock for QS in hyprland.lua, then check typing, clicks and hover by hand (none of it could be automated)
- [ ] **P7** Palette center (switch/save palettes, `theme set` IPC), screenshare picker, wallpaper picker + matugen + app reload scripts
- [ ] Workspaces: app icons per workspace
- [x] Tray menus styled with our theme (`modules/tray/TrayMenu.qml`, submenus expand inline)
- [ ] Move `modules/launcher/SearchField.qml` and the duplicated `IconButton`s into `components/`
