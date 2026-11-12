pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.core

// Owns "which panel is open, where, and why". UI (OverlayWindow) only reacts to this.
// Panels opened from the bar are anchored to the PILL (not the button), so every
// button in one pill opens its panel in the same place; switching between them
// swaps the content in place.
//
// Attached panels: a panel whose placement.attach.to === X opens beside X whenever
// X opens (e.g. clipboard left of launcher). Opening an attached panel directly
// opens its host and focuses the attached one. `focusId` says which of the two has
// keyboard focus; moveFocus("left"|"right") walks between them.
Singleton {
    id: root

    property string openId: ""
    property string source: ""      // "bar" | "ipc"
    property string screenName: ""  // output the panel shows on
    property string pillSide: ""    // "left" | "center" | "right" when source === "bar"
    property var anchor: null       // { x, y, width, height } of the pill, in bar-window coords
    property string focusId: ""     // openId or attachedId: who gets keyboard focus
    // True when the current panel replaced another one in the SAME spot (same pill,
    // same source, same screen): the overlay then morphs in place. Any other switch
    // (e.g. left pill → right pill) snaps to the new spot instead of sliding across.
    property bool morph: false

    readonly property bool isOpen: openId !== ""
    // Panel opened beside openId ("" = none) and the side it sits on.
    readonly property string attachedId: attachedFor(openId)
    readonly property string attachedSide: attachedId ? (Registry.placement(attachedId).attach?.side ?? "left") : ""

    function attachedFor(id: string): string {
        if (!id)
            return "";
        for (const k of Object.keys(Registry.panels))
            if (Registry.placement(k).attach?.to === id)
                return k;
        return "";
    }

    // The panel that owns the slot for `id` (its attach host, or itself).
    function hostOf(id: string): string {
        const to = Registry.placement(id).attach?.to;
        return to && Registry.hasPanel(to) ? to : id;
    }

    function isShowing(id: string): bool {
        return isOpen && (openId === id || attachedId === id);
    }

    function toggle(id: string, src: string, pill: var): void {
        if (isShowing(id))
            close();
        else
            open(id, src, pill);
    }

    function open(id: string, src: string, pill: var): void {
        if (!Registry.hasPanel(id)) {
            console.warn("PanelManager: unknown panel", id);
            return;
        }
        const host = hostOf(id);
        const nextSide = pill ? (pill.side ?? "") : "";
        const nextScreen = pill ? (pill.barScreen?.name ?? "") : (Hyprland.focusedMonitor?.name ?? "");
        // Set before anything else changes, so the overlay's Behaviors see it.
        morph = isOpen && src === source && nextSide === pillSide && nextScreen === screenName;
        if (pill) {
            const p = pill.mapToItem(null, 0, 0);
            anchor = {
                x: p.x,
                y: p.y,
                width: pill.width,
                height: pill.height
            };
            pillSide = pill.side;
            screenName = pill.barScreen?.name ?? "";
        } else {
            anchor = null;
            pillSide = "";
            screenName = Hyprland.focusedMonitor?.name ?? "";
        }
        source = src;
        openId = host;
        focusId = id;
    }

    function close(): void {
        openId = "";
    }

    // Keyboard focus between a panel and its attached neighbour.
    function focus(id: string): void {
        if (isShowing(id))
            focusId = id;
    }

    function moveFocus(dir: string): bool {
        if (!attachedId)
            return false;
        const back = attachedSide === "left" ? "right" : "left";
        if (focusId === openId && dir === attachedSide) {
            focusId = attachedId;
            return true;
        }
        if (focusId === attachedId && dir === back) {
            focusId = openId;
            return true;
        }
        return false;
    }
}
