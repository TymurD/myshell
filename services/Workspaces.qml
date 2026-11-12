pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.config

Singleton {
    id: root

    readonly property int focusedId: Hyprland.focusedWorkspace?.id ?? 1
    readonly property var all: Hyprland.workspaces.values.filter(w => w.id > 0)

    // 1..max(persistent, highest existing workspace)
    readonly property var ids: {
        const persistent = Config.workspaces.persistent ?? 6;
        const highest = all.reduce((m, w) => Math.max(m, w.id), 0);
        return Array.from({
            length: Math.max(persistent, highest)
        }, (_, i) => i + 1);
    }

    function get(id: int): var {
        return all.find(w => w.id === id) ?? null;
    }

    function occupied(id: int): bool {
        const w = get(id);
        return w !== null && w.toplevels.values.length > 0;
    }

    function activate(id: int): void {
        const w = get(id);
        if (w)
            w.activate();
        else
            // hyprland.lua config: dispatch takes a Lua expression
            Hyprland.dispatch(`hl.dsp.focus({ workspace = ${id} })`);
    }
}
