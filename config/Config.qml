pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "merge.js" as Merge

// Settings = <repo>/settings.default.json (tracked defaults) deep-merged with the
// user's overrides in $XDG_CONFIG_HOME/myshell/settings.json (untracked). Objects merge
// per key; arrays and scalars replace. Both files are watched and hot-reloaded.
// The settings panel writes overrides through set()/reset(); the user file only ever
// holds values that differ from the defaults.
Singleton {
    id: root

    readonly property string userPath: (Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config") + "/myshell/settings.json"
    readonly property string userDir: userPath.slice(0, userPath.lastIndexOf("/"))

    // Fallback when settings.default.json is missing a key (or the file itself).
    readonly property var fallback: ({
            palette: "default",
            bar: {
                height: 34,
                margin: 12,
                left: [],
                center: ["clock"],
                right: [],
                panelAt: {
                    left: "edge-left",
                    center: "pill",
                    right: "edge-right"
                }
            },
            workspaces: {
                persistent: 6
            },
            keyboard: {
                names: {}
            },
            clock: {
                format: "HH:mm"
            },
            dashboard: {
                left: [],
                right: []
            },
            network: {
                showSpeed: false
            },
            media: {
                maxWidth: 240
            }
        })

    property var defaultsFile: ({})
    property var overrides: ({})
    property bool userFileBroken: false
    property bool userFileMissing: false

    readonly property var defaults: Merge.deepMerge(fallback, defaultsFile)
    readonly property var merged: Merge.deepMerge(defaults, overrides)

    readonly property string palette: merged.palette ?? "default"
    readonly property var bar: merged.bar ?? {}
    readonly property var panels: merged.panels ?? {}
    readonly property var workspaces: merged.workspaces ?? {}
    readonly property var keyboard: merged.keyboard ?? {}
    readonly property var clock: merged.clock ?? {}
    readonly property var dashboard: merged.dashboard ?? {}
    readonly property var weather: merged.weather ?? {}
    readonly property var network: merged.network ?? {}
    readonly property var media: merged.media ?? {}
    readonly property var launcher: merged.launcher ?? {}
    readonly property var clipboard: merged.clipboard ?? {}
    readonly property var notifications: merged.notifications ?? {}
    readonly property var lock: merged.lock ?? {}
    readonly property var session: merged.session ?? {}
    readonly property var sysstats: merged.sysstats ?? {}
    readonly property var timers: merged.timers ?? {}
    readonly property var brightness: merged.brightness ?? {}

    function get(path: string): var {
        return Merge.getPath(merged, path);
    }

    function isOverridden(path: string): bool {
        return Merge.getPath(overrides, path) !== undefined;
    }

    function set(path: string, value: var): void {
        write(Merge.overridesAfterSet(defaults, overrides, path, value));
    }

    function reset(path: string): void {
        write(Merge.withoutPath(overrides, path));
    }

    function write(next: var): void {
        if (userFileBroken) {
            console.warn("Config: not saving,", userPath, "has a syntax error. Fix or remove it first.");
            return;
        }
        overrides = next;
        pendingText = JSON.stringify(next, null, 2) + "\n";
        if (!mkdir.running)
            mkdir.running = true;
    }

    property string pendingText: ""

    function parse(text: string, what: string): var {
        if (text.trim() === "")
            return {};
        try {
            const v = JSON.parse(text);
            return v !== null && typeof v === "object" && !Array.isArray(v) ? v : {};
        } catch (e) {
            console.warn("Config: invalid JSON in", what + ":", e.message);
            return null;
        }
    }

    // The user file's directory may not exist yet; create it, then write.
    Process {
        id: mkdir
        command: ["mkdir", "-p", root.userDir]
        onExited: code => {
            if (code !== 0) {
                console.warn("Config: could not create", root.userDir);
                return;
            }
            userFile.setText(root.pendingText);
        }
    }

    FileView {
        path: Quickshell.shellPath("settings.default.json")
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            const v = root.parse(text(), "settings.default.json");
            if (v !== null)
                root.defaultsFile = v;
        }
        onLoadFailed: err => console.warn("Config: failed to load settings.default.json:", FileViewError.toString(err))
    }

    // FileView only watches a file that existed when it loaded, so while the user file
    // is missing (never created, or deleted) poll for it to appear.
    Timer {
        interval: 2000
        repeat: true
        running: root.userFileMissing
        onTriggered: userFile.reload()
    }

    FileView {
        id: userFile
        path: root.userPath
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            const v = root.parse(text(), root.userPath);
            root.userFileMissing = false;
            root.userFileBroken = v === null;
            root.overrides = v ?? {};
        }
        onLoadFailed: err => {
            // Missing file = no overrides.
            root.userFileBroken = false;
            root.userFileMissing = err === FileViewError.FileNotFound;
            root.overrides = {};
            if (err !== FileViewError.FileNotFound)
                console.warn("Config: failed to load", root.userPath + ":", FileViewError.toString(err));
        }
    }
}
