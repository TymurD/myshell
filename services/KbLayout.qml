pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.config

// Active keyboard layout. `changed` fires on every switch (for the OSD).
Singleton {
    id: root

    property string full: ""
    readonly property string short: Config.keyboard.names?.[full] ?? full.slice(0, 2).toUpperCase()

    signal switched(string full)

    function next(): void {
        Quickshell.execDetached(["hyprctl", "switchxkblayout", "all", "next"]);
    }

    Connections {
        target: Hyprland
        function onRawEvent(event: HyprlandEvent): void {
            if (event.name !== "activelayout")
                return;
            // data: "<keyboard-name>,<layout-name>"
            const name = event.data.slice(event.data.indexOf(",") + 1);
            if (name !== root.full) {
                root.full = name;
                root.switched(name);
            }
        }
    }

    Process {
        running: true
        command: ["hyprctl", "devices", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                const kb = JSON.parse(text).keyboards;
                const main = kb.find(k => k.main) ?? kb[kb.length - 1];
                if (main)
                    root.full = main.active_keymap;
            }
        }
    }
}
