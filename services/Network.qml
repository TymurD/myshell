pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Networking
import qs.config

// Active connection summary (Quickshell.Networking / NetworkManager) + optional throughput.
Singleton {
    id: root

    readonly property var devices: Networking.devices.values
    readonly property var wired: devices.find(d => d.type === DeviceType.Wired && d.connected) ?? null
    readonly property var wifi: devices.find(d => d.type === DeviceType.Wifi) ?? null
    readonly property var wifiNetwork: wifi?.networks.values.find(n => n.connected) ?? null

    readonly property string kind: wired ? "wired" : wifiNetwork ? "wifi" : "none"
    readonly property bool connected: kind !== "none"
    readonly property string name: wired ? (wired.network?.name || "Ethernet") : wifiNetwork ? wifiNetwork.name : Networking.wifiEnabled ? "Disconnected" : "Wi-Fi off"
    readonly property string iface: wired?.name ?? (wifiNetwork ? wifi.name : "")
    // 0..1 (normalised in case the backend reports 0..100)
    readonly property real strength: {
        const s = wifiNetwork?.signalStrength ?? 0;
        return s > 1 ? s / 100 : s;
    }

    function icon(): int {
        if (kind === "wired")
            return 0xF0200; // ethernet
        if (kind === "none")
            return Networking.wifiEnabled ? 0xF092D : 0xF092E; // wifi-strength-off-outline / wifi-off
        const steps = [0xF091F, 0xF0922, 0xF0925, 0xF0928]; // wifi-strength-1..4
        return steps[Math.min(3, Math.floor(strength * 4))];
    }

    // ---- throughput (bytes/s), only polled when enabled in settings ----
    readonly property bool speedEnabled: Config.network.showSpeed ?? false
    property real rxRate: 0
    property real txRate: 0
    property var _last: null

    function formatRate(b: real): string {
        if (b >= 1048576)
            return (b / 1048576).toFixed(1) + "M";
        if (b >= 1024)
            return (b / 1024).toFixed(0) + "K";
        return b.toFixed(0) + "B";
    }

    FileView {
        id: netdev
        path: "/proc/net/dev"
    }

    Timer {
        interval: 2000
        repeat: true
        running: root.speedEnabled && root.iface !== ""
        triggeredOnStart: true
        onTriggered: {
            netdev.reload();
            const line = netdev.text().split("\n").find(l => l.trim().startsWith(root.iface + ":"));
            if (!line)
                return;
            const f = line.split(":")[1].trim().split(/\s+/).map(Number);
            const now = Date.now();
            if (root._last && root._last.iface === root.iface) {
                const dt = (now - root._last.t) / 1000;
                root.rxRate = (f[0] - root._last.rx) / dt;
                root.txRate = (f[8] - root._last.tx) / dt;
            }
            root._last = {
                iface: root.iface,
                t: now,
                rx: f[0],
                tx: f[8]
            };
        }
    }
}
