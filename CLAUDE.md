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
services/            singletons holding state/logic: Time, KbLayout, Workspaces, ... (no UI)
modules/<id>/        one folder per feature: <Name>Bar.qml, <Name>Panel.qml, optional <Name>Card.qml
scripts/             helper shell scripts (share picker, palette apply/reload, ...)
```

Imports use Quickshell's `qs.` root (`import qs.services`, `import qs.theme`, …). No qmldir files needed. Singletons need `pragma Singleton` + a `Singleton {}` root.

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
- **Opened from the bar, position is decided by the pill, not the button.** Every button in one pill opens its panel in the same spot. Clicking another button in that pill while a panel is open swaps the content in place: size and position animate and the content cross-fades. The spot per pill is in `settings.json` → `bar.panelAt`. Defaults: left → `"edge-left"`, center → `"pill"` (top, centered under the center pill, used by the dashboard), right → `"edge-right"`. Panels always hang from the top, just below the bar.
- Per-panel placement lives in `Registry.panels[id].placement` and can be overridden in `settings.json` → `panels.<id>`:
  - `fromBar` (optional): overrides the pill's spot for this one panel. Avoid it, since it breaks the "same place per pill" rule.
  - `fromIpc`: `"center-top"` (default for keybinds) | `"center"` | `"edge-left"` | `"edge-right"`.
  - `"center"` = vertically centered on screen (launcher, session menu via keybind).
  - `keyboard: true` gives the panel exclusive keyboard focus (launcher, clipboard, lock-style input).
  - `attach: { to, side }`: open beside another panel (clipboard sits left of the launcher, arrows move between them).
- Animate in and out with `Anim` tokens. The overlay keeps the last panel loaded while it fades out.

## Theme & animation rules

- **Never hard-code colors, font sizes, radii or durations in modules.** Use `Theme.*` and `Anim.*`. Add a token if one is missing.
- Palette file = flat JSON of token → `#aarrggbb`/`#rrggbb` (see `palettes/default.json`). Switching = change `palette` in settings.json (later: palette panel + `theme set` IPC).
- Planned matugen flow: wallpaper → `matugen` → `palettes/generated.json` + templates for other apps → `scripts/apply-palette` reloads them.
- Icons: Nerd Font glyphs via `Icon { code: 0xF0150 }`.

## Config vs state

- `settings.json` (repo, tracked): things the user edits by hand.
- `~/.local/state/myshell/*.json` (via `Quickshell.statePath`): runtime state such as notification history, DND/muted apps, timers/alarms, saved palettes, clipboard pins. Write it from services only.

## IPC

`core/Ipc.qml`. Target names are lowercase nouns, functions are verbs:

- `panels toggle|open <id>`, `panels close`, `panels list`
- `keyboard next`
- planned: `lock lock`, `sharepicker pick <fifo>`, `theme set <palette>`, `timers start <sec>`

## Hyprland integration (Lua config)

`hyprctl dispatch` takes **Lua expressions** with this config (e.g. `hyprctl dispatch 'hl.dsp.focus({ workspace = 3 })'`). In QML, prefer native methods (`HyprlandWorkspace.activate()`). If you must use `Hyprland.dispatch(...)`, pass Lua. `hyprctl switchxkblayout` is a normal command, not a dispatcher.

Snippets for `hyprland.lua`:

```lua
hl.exec_cmd("qs -c myshell")                       -- replaces waybar (and later mako, polkit-gnome)
hl.exec_cmd("wl-paste --watch cliphist store")     -- clipboard history
local qs = "qs -c myshell ipc call "
hl.bind(mainMod .. " + D", hl.dsp.exec_cmd(qs .. "panels toggle launcher"))
hl.bind(mainMod .. " + BackSpace", hl.dsp.exec_cmd(qs .. "lock lock"))
-- misc: allow_session_lock_restore = true  (MUST be set before using the QS lock screen)
```

Edit `~/.config/hypr/hyprland.lua` only when the user asks. Never remove waybar/mako/hyprlock/polkit-gnome execs until the replacing module works.

## Notes / answers

- **Lock screen:** yes. `WlSessionLock` + `PamContext` (Quickshell.Services.Pam). Set Hyprland `misc.allow_session_lock_restore = true` so a crashed qs can be restarted (`qs -c myshell`) instead of leaving a dead red lock screen. Keep hyprlock as a fallback bind until it's proven.
- **Polkit:** yes. `Quickshell.Services.Polkit` → `PolkitAgent` and our own dialog. Remove polkit-gnome when it ships, since only one agent can register.
- **Screenshare picker:** yes, via xdg-desktop-portal-hyprland. In `~/.config/hypr/xdph.conf` set `screencopy { custom_picker_binary = <repo>/scripts/share-picker }`. The script creates a FIFO and calls `ipc call sharepicker pick <fifo>`. The QML picker writes the selection (`[SELECTION]/screen:<name>` or `window:<handle>`, so check the xdph source for the exact format) into the FIFO, and the script prints it to stdout.
- **Notifications:** only one `NotificationServer` can own the D-Bus name, so kill mako first.
- **Battery / TLP:** profiles are switched through `PowerProfiles` (Quickshell.Services.UPower). tlp-pd owns `net.hadess.PowerProfiles`, so Saver/Balanced/Performance map onto TLP profiles with no root or sudo. Battery data comes from `UPower.displayDevice`. Logic is in `services/Battery.qml`.
- **Volume:** not controlled. The media panel shows default sink volume read-only (Services.Pipewire).
- **Weather:** Open-Meteo (no API key), coords in `settings.json` → `weather`.

## Gotchas

- Layer-shell keyboard focus: default `None`. Use `Exclusive` only while a typing panel is open, or you steal input from apps.
- Long-running/blocking work → `Process` / `FileView` (async). Never busy-loop in JS; poll with `Timer`.
- `Process` + `StdioCollector`/`SplitParser` for CLI tools (cliphist, nmcli fallback, sensors). Use `Quickshell.execDetached` for fire-and-forget.
- `Hyprland.workspaces` / `toplevels` are ObjectModels: use `.values`.
- `UPower.displayDevice.percentage` is 0–1.
- Waybar running at the same time pushes our bar down, so panel offsets look wrong until waybar is removed.

## Roadmap

- [x] **P1 Skeleton**: config/theme/palette, Registry, PanelManager, OverlayWindow, 3-pill bar, IPC; clock, workspaces, keyboard bar items; placeholders for the rest
- [x] Per-pill panel placement + in-place swap between panels of one pill
- [x] Battery: bar (icon + %) and panel (charge, draw, time left, energy, health, TLP profile buttons)
- [x] Informative bar items: network (icon + SSID/wired name, optional ↓↑ rates), media (state + title · artist, right click = play/pause), tray (real icons, activate, app menus)
- [ ] **P2 Panel system polish**: media pill → player morph animation, attach (launcher+clipboard), keyboard OSD overlay, per-screen behaviour
- [ ] **P3 Lock + polkit + session menu** (shutdown/reboot/lock/logout)
- [ ] **P4** Notifications (toasts, center with full list, DND, per-app mute; replace mako; bar shows unread count / latest summary), network panel (wifi list, connect, toggle), tray menus styled
- [ ] **P5** App launcher (replace fuzzel) + clipboard history (cliphist, images)
- [ ] **P6** Media (MPRIS: art, title, seek bar, prev/next, volume text; mini pill → expanded), dashboard (calendar center; configurable side slots: CPU/GPU/RAM/temps, weather today + week, timers), timers & alarms
- [ ] **P7** Palette center (switch/save palettes), screenshare picker, wallpaper picker + matugen + app reload scripts
- [ ] Workspaces: app icons per workspace
