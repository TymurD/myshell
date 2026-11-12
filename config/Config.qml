pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// User settings, read from <repo>/settings.json and hot-reloaded on change.
// Defaults below apply when a key is missing from the file.
Singleton {
    id: root

    readonly property string palette: adapter.palette
    readonly property var bar: adapter.bar
    readonly property var panels: adapter.panels
    readonly property var workspaces: adapter.workspaces
    readonly property var keyboard: adapter.keyboard
    readonly property var clock: adapter.clock
    readonly property var dashboard: adapter.dashboard
    readonly property var weather: adapter.weather
    readonly property var network: adapter.network
    readonly property var media: adapter.media
    readonly property var launcher: adapter.launcher
    readonly property var clipboard: adapter.clipboard
    readonly property var notifications: adapter.notifications
    readonly property var lock: adapter.lock
    readonly property var session: adapter.session
    readonly property var sysstats: adapter.sysstats
    readonly property var timers: adapter.timers

    FileView {
        path: Quickshell.shellPath("settings.json")
        watchChanges: true
        onFileChanged: reload()
        onLoadFailed: err => console.warn("Config: failed to load settings.json:", FileViewError.toString(err))

        JsonAdapter {
            id: adapter

            property string palette: "default"
            property var bar: ({
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
                })
            property var panels: ({})
            property var workspaces: ({
                    persistent: 6
                })
            property var keyboard: ({
                    names: {}
                })
            property var clock: ({
                    format: "HH:mm"
                })
            property var dashboard: ({
                    left: [],
                    right: []
                })
            property var weather: ({})
            property var network: ({
                    showSpeed: false
                })
            property var media: ({
                    maxWidth: 240
                })
            property var launcher: ({})
            property var clipboard: ({})
            property var notifications: ({})
            property var lock: ({})
            property var session: ({})
            property var sysstats: ({})
            property var timers: ({})
        }
    }
}
