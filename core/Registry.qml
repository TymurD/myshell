pragma Singleton

import QtQuick
import Quickshell
import qs.config

// Central list of modules (bar items) and panels (expanded views).
// Add a module: create modules/<id>/, then add entries here.
Singleton {
    id: root

    // Bar items. `bar`: path under modules/. `panel`: panel id opened on click ("" = none).
    readonly property var modules: ({
            session: {
                bar: "session/SessionBar.qml",
                panel: "session"
            },
            workspaces: {
                bar: "workspaces/WorkspacesBar.qml",
                panel: ""
            },
            keyboard: {
                bar: "keyboard/KeyboardBar.qml",
                panel: ""
            },
            battery: {
                bar: "battery/BatteryBar.qml",
                panel: "battery"
            },
            clock: {
                bar: "clock/ClockBar.qml",
                panel: "dashboard"
            },
            media: {
                bar: "media/MediaBar.qml",
                panel: "media"
            },
            tray: {
                bar: "tray/TrayBar.qml",
                panel: ""
            },
            network: {
                bar: "network/NetworkBar.qml",
                panel: "network"
            },
            notifications: {
                bar: "notifications/NotificationsBar.qml",
                panel: "notifications"
            }
        })

    // Panels. `url`: path under modules/ ("" = placeholder until implemented).
    // Opened from the bar, a panel's position is decided by the PILL it came from
    // (settings.json → bar.panelAt), so every button in one pill opens in the same spot.
    // placement.fromBar: optional per-panel override of that: "pill" | "edge-left" | "edge-right"
    // placement.fromIpc: "pill-less" position for keybinds: "center-top" | "center" | "edge-left" | "edge-right"
    // placement.keyboard: panel needs exclusive keyboard focus (typing)
    // placement.attach: { to: <panelId>, side: "left"|"right" } opens beside another panel
    // Any field can be overridden per panel in settings.json → "panels": { <id>: {...} }.
    readonly property var panels: ({
            battery: {
                url: "battery/BatteryPanel.qml",
                placement: {
                    fromIpc: "center-top"
                }
            },
            dashboard: {
                url: "dashboard/DashboardPanel.qml",
                placement: {
                    fromIpc: "center-top"
                }
            },
            session: {
                url: "session/SessionPanel.qml",
                placement: {
                    fromIpc: "center"
                }
            },
            media: {
                url: "media/MediaPanel.qml",
                placement: {
                    fromIpc: "center-top"
                }
            },
            network: {
                url: "network/NetworkPanel.qml",
                placement: {
                    fromIpc: "center-top"
                }
            },
            notifications: {
                url: "notifications/NotificationsPanel.qml",
                placement: {
                    fromIpc: "center-top"
                }
            },
            launcher: {
                url: "launcher/LauncherPanel.qml",
                placement: {
                    fromIpc: "center",
                    keyboard: true
                }
            },
            clipboard: {
                url: "clipboard/ClipboardPanel.qml",
                placement: {
                    attach: {
                        to: "launcher",
                        side: "left"
                    }
                }
            },
            timers: {
                url: "timers/TimersPanel.qml",
                placement: {
                    fromIpc: "center-top"
                }
            },
            palette: {
                url: "",
                placement: {
                    fromIpc: "center-top"
                }
            }
        })

    function barUrl(id: string): string {
        const m = modules[id];
        if (!m) {
            console.warn("Registry: unknown module", id);
            return "";
        }
        return Qt.resolvedUrl("../modules/" + m.bar);
    }

    function panelForModule(id: string): string {
        return modules[id]?.panel ?? "";
    }

    function hasPanel(id: string): bool {
        return panels[id] !== undefined;
    }

    function panelUrl(id: string): string {
        const p = panels[id];
        if (!p)
            return "";
        return p.url ? Qt.resolvedUrl("../modules/" + p.url) : Qt.resolvedUrl("../components/PlaceholderPanel.qml");
    }

    // Registry defaults merged with settings.json overrides.
    function placement(id: string): var {
        const base = panels[id]?.placement ?? {};
        const over = Config.panels?.[id] ?? {};
        return Object.assign({
            fromIpc: "center-top",
            keyboard: false
        }, base, over);
    }
}
