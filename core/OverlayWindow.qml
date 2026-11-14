import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.config
import qs.core
import qs.theme
// Panels are loaded by URL, and Quickshell only scans a module folder (so its
// sibling types and `import qs.modules.<id>` resolve) when some statically loaded
// file imports it. Import every panel folder here. Add new panel folders too.
import qs.modules.battery
import qs.modules.brightness
import qs.modules.clipboard
import qs.modules.dashboard
import qs.modules.launcher
import qs.modules.media
import qs.modules.network
import qs.modules.session
import qs.modules.settings
import qs.modules.sysstats
import qs.modules.timers
import qs.modules.weather

// Fullscreen transparent layer per screen that hosts expanded panels.
// Input is masked to the visible panel(s), so the rest of the screen stays clickable.
//
// Two PanelSlots take turns. Each has its own panel, open progress `t` (0 → 1 on
// open, 1 → 0 on close) and a snapshot of how its panel was opened (source, pill,
// anchor), so its rect = lerp(origin, target, t) never depends on the other slot.
//  - From the bar, the panel unrolls downward in place: a bar-high strip (pill
//    coloured "shell") grows to full height and the clip reveals the content; on
//    close it rolls back up. It never travels from the pill's position.
//  - From a keybind, origin = target nudged up: fade + slide.
//  - Switching panels while open: the current slot rolls its panel up while the
//    other slot loads the new one and unrolls it, both at the same time.
// An attached panel (placement.attach) gets its own rect beside its slot's main one.
PanelWindow {
    id: root

    property var barWindow

    readonly property bool shown: PanelManager.isOpen && PanelManager.screenName === (screen?.name ?? "")
    // Panel this screen should show ("" = none).
    readonly property string wantId: shown ? PanelManager.openId : ""

    property int activeSlot: 0
    readonly property PanelSlot cur: activeSlot === 0 ? slotA : slotB
    readonly property PanelSlot other: activeSlot === 0 ? slotB : slotA

    function sync(): void {
        if (wantId === "") {
            cur.tTarget = 0;
        } else if (wantId === cur.loadedId && cur.t > 0) {
            cur.tTarget = 1; // reopened mid-close: grow back
        } else if (cur.t <= 0) {
            cur.load(wantId);
            cur.tTarget = 1;
        } else if (wantId === other.loadedId && other.t > 0) {
            // Switched back to the panel that is still rolling up: reverse both.
            cur.tTarget = 0;
            activeSlot = 1 - activeSlot;
            cur.tTarget = 1;
        } else {
            // Swap: close this one and open the new panel in the other slot at once.
            const next = other;
            cur.tTarget = 0;
            next.load(wantId);
            activeSlot = 1 - activeSlot;
            next.tTarget = 1;
        }
    }

    onWantIdChanged: sync()
    Component.onCompleted: sync()

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "myshell-overlay"
    // Exclusive for every panel, and constant while open: changing the keyboard mode
    // while a panel is showing (e.g. battery → session in one pill) makes Hyprland
    // drop the focus grab, which closed everything. Click-outside closes anyway.
    WlrLayershell.keyboardFocus: shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    mask: Region {
        item: slotA.panel.visible ? slotA.panel : null
        Region {
            item: slotA.side.visible ? slotA.side : null
        }
        Region {
            item: slotB.panel.visible ? slotB.panel : null
        }
        Region {
            item: slotB.side.visible ? slotB.side : null
        }
    }

    HyprlandFocusGrab {
        // Activated once the panel has an input region: a grab on a surface with an
        // empty mask is cleared by Hyprland right away.
        active: root.shown && root.cur.settled
        // Inside a grab Hyprland gives keyboard focus to the whitelisted surface under
        // the pointer, so a whitelisted bar steals typing from the launcher/clipboard
        // while hovered. Typing panels grab only the overlay; a bar click then closes them.
        windows: root.cur.placement.keyboard ? [root] : [root, root.barWindow]
        onCleared: PanelManager.close()
    }

    PanelSlot {
        id: slotA
        isActive: root.activeSlot === 0
        shown: root.shown
    }

    PanelSlot {
        id: slotB
        isActive: root.activeSlot === 1
        shown: root.shown
    }
}
