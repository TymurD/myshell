pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Networking
import qs.config
import qs.core

// Active connection summary (Quickshell.Networking / NetworkManager), wifi list and
// actions for the panel, IP details (nmcli) and optional throughput.
Singleton {
    id: root

    readonly property var devices: Networking.devices.values
    readonly property var wiredDevice: devices.find(d => d.type === DeviceType.Wired && d.connected) ?? devices.find(d => d.type === DeviceType.Wired) ?? null
    readonly property var wired: wiredDevice?.connected ? wiredDevice : null
    readonly property var wifi: devices.find(d => d.type === DeviceType.Wifi) ?? null
    readonly property var wifiNetworks: wifi?.networks.values ?? []
    readonly property var wifiNetwork: wifiNetworks.find(n => n.connected) ?? null

    readonly property bool wifiEnabled: Networking.wifiEnabled
    readonly property bool wifiHardwareEnabled: Networking.wifiHardwareEnabled

    readonly property string kind: wired ? "wired" : wifiNetwork ? "wifi" : "none"
    readonly property bool connected: kind !== "none"
    readonly property string name: wired ? (wired.network?.name || "Ethernet") : wifiNetwork ? wifiNetwork.name : Networking.wifiEnabled ? "Disconnected" : "Wi-Fi off"
    readonly property string iface: wired?.name ?? (wifiNetwork ? wifi.name : "")
    // 0..1
    readonly property real strength: norm(wifiNetwork?.signalStrength ?? 0)

    // The panel is open somewhere: scan for networks and measure throughput meanwhile.
    readonly property bool panelOpen: PanelManager.openId === "network"

    function norm(s: real): real {
        return s > 1 ? s / 100 : s;
    }

    function strengthIcon(s: real, locked: bool): int {
        const i = Math.min(3, Math.floor(norm(s) * 4));
        return locked ? [0xF0921, 0xF0924, 0xF0927, 0xF092A][i] : [0xF091F, 0xF0922, 0xF0925, 0xF0928][i];
    }

    function icon(): int {
        if (kind === "wired")
            return 0xF0200; // ethernet
        if (kind === "none")
            return Networking.wifiEnabled ? 0xF092D : 0xF092E; // wifi-strength-off-outline / wifi-off
        return strengthIcon(strength, false);
    }

    function secured(n: var): bool {
        const s = n?.security ?? WifiSecurityType.Open;
        return s !== WifiSecurityType.Open && s !== WifiSecurityType.Owe && s !== WifiSecurityType.Unknown;
    }
    function securityText(n: var): string {
        const sec = n?.security ?? WifiSecurityType.Unknown;
        return sec === WifiSecurityType.Unknown ? "" : WifiSecurityType.toString(sec);
    }
    function stateText(s: int): string {
        switch (s) {
        case ConnectionState.Connecting:
            return "Connecting…";
        case ConnectionState.Connected:
            return "Connected";
        case ConnectionState.Disconnecting:
            return "Disconnecting…";
        case ConnectionState.Disconnected:
            return "Disconnected";
        default:
            return "Unknown";
        }
    }
    function failText(r: int): string {
        switch (r) {
        case ConnectionFailReason.NoSecrets:
            return "Wrong or missing password";
        case ConnectionFailReason.WifiAuthTimeout:
            return "Authentication timed out";
        case ConnectionFailReason.WifiNetworkLost:
            return "Network lost";
        case ConnectionFailReason.WifiClientDisconnected:
        case ConnectionFailReason.WifiClientFailed:
            return "Connection failed";
        default:
            return "Couldn't connect";
        }
    }

    // Current network first, then by signal (in 4 coarse steps so the list doesn't jitter), then name.
    readonly property var sortedNetworks: wifiNetworks.filter(n => n.name !== "").sort((a, b) => {
        if (a.connected !== b.connected)
            return a.connected ? -1 : 1;
        const sa = Math.min(3, Math.floor(norm(a.signalStrength) * 4));
        const sb = Math.min(3, Math.floor(norm(b.signalStrength) * 4));
        if (sa !== sb)
            return sb - sa;
        if (a.known !== b.known)
            return a.known ? -1 : 1;
        return a.name.localeCompare(b.name);
    })

    // ---- actions ----
    function setWifiEnabled(on: bool): void {
        Networking.wifiEnabled = on;
    }
    function connectTo(n: var): void {
        n?.connect();
    }
    function connectWithPsk(n: var, psk: string): void {
        n?.connectWithPsk(psk);
    }
    function disconnectFrom(n: var): void {
        n?.disconnect();
    }
    function forget(n: var): void {
        n?.forget();
    }

    Binding {
        when: root.wifi !== null && root.panelOpen && root.wifiEnabled
        target: root.wifi
        property: "scannerEnabled"
        value: true
    }

    // ---- IP details via nmcli (only while the panel is open) ----
    property string ip: ""
    property string gateway: ""
    property string dns: ""

    function refreshDetails(): void {
        if (iface === "") {
            ip = gateway = dns = "";
            return;
        }
        details.command = ["nmcli", "-t", "-f", "IP4.ADDRESS,IP4.GATEWAY,IP4.DNS", "device", "show", iface];
        details.running = true;
    }

    onPanelOpenChanged: if (panelOpen)
        refreshDetails()
    onIfaceChanged: if (panelOpen)
        refreshDetails()
    onKindChanged: if (panelOpen)
        refreshDetails()

    Process {
        id: details
        stdout: StdioCollector {
            onStreamFinished: {
                const get = key => text.split("\n").filter(l => l.startsWith(key)).map(l => l.slice(l.indexOf(":") + 1)).filter(v => v !== "");
                root.ip = get("IP4.ADDRESS")[0] ?? "";
                root.gateway = get("IP4.GATEWAY")[0] ?? "";
                root.dns = get("IP4.DNS").join(", ");
            }
        }
    }

    // ---- throughput (bytes/s): bar setting or while the panel is open ----
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
        running: (root.speedEnabled || root.panelOpen) && root.iface !== ""
        triggeredOnStart: true
        onTriggered: {
            netdev.reload();
            const line = netdev.text().split("\n").find(l => l.trim().startsWith(root.iface + ":"));
            if (!line)
                return;
            const f = line.split(":")[1].trim().split(/\s+/).map(Number);
            const now = Date.now();
            if (root._last && root._last.iface === root.iface && now - root._last.t < 5000) {
                const dt = (now - root._last.t) / 1000;
                root.rxRate = Math.max(0, (f[0] - root._last.rx) / dt);
                root.txRate = Math.max(0, (f[8] - root._last.tx) / dt);
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
