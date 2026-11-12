pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.core

// Owns "which panel is open, where, and why". UI (OverlayWindow) only reacts to this.
// Panels opened from the bar are anchored to the PILL (not the button), so every
// button in one pill opens its panel in the same place; switching between them
// swaps the content in place.
Singleton {
    id: root

    property string openId: ""
    property string source: ""      // "bar" | "ipc"
    property string screenName: ""  // output the panel shows on
    property string pillSide: ""    // "left" | "center" | "right" when source === "bar"
    property var anchor: null       // { x, width } of the pill, in bar-window coords

    readonly property bool isOpen: openId !== ""

    function toggle(id: string, src: string, pill: var): void {
        if (openId === id)
            close();
        else
            open(id, src, pill);
    }

    function open(id: string, src: string, pill: var): void {
        if (!Registry.hasPanel(id)) {
            console.warn("PanelManager: unknown panel", id);
            return;
        }
        if (pill) {
            const p = pill.mapToItem(null, 0, 0);
            anchor = {
                x: p.x,
                width: pill.width
            };
            pillSide = pill.side;
            screenName = pill.barScreen?.name ?? "";
        } else {
            anchor = null;
            pillSide = "";
            screenName = Hyprland.focusedMonitor?.name ?? "";
        }
        source = src;
        openId = id;
    }

    function close(): void {
        openId = "";
    }
}
