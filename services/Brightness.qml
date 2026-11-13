pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Screen backlight. Reads /sys/class/backlight/<device>/brightness, writes via
// brightnessctl (which goes through logind's SetBrightness: no root, no udev rule).
// settings.json → brightness: { device: "" (= first backlight), step: 5, min: 1 }
Singleton {
    id: root

    property string device: ""
    property int max: 0
    property int raw: 0                  // last known (or optimistically set) raw value
    readonly property bool available: device !== "" && max > 0
    readonly property int percent: max > 0 ? Math.round(raw * 100 / max) : 0
    readonly property int step: Config.brightness?.step ?? 5
    readonly property int minPercent: Config.brightness?.min ?? 1

    // Pending write; flushed by writeTimer so dragging a slider doesn't spawn a process per pixel.
    property int pendingRaw: -1

    function setPercent(p: real): void {
        if (!available)
            return;
        const pct = Math.max(minPercent, Math.min(100, p));
        raw = Math.round(pct * max / 100);
        pendingRaw = raw;
        if (!writeTimer.running)
            writeTimer.start();
    }

    function up(): void {
        setPercent(percent + step);
    }
    function down(): void {
        setPercent(percent - step);
    }

    function icon(): int {
        // nf-md-brightness_5 (dim) / _6 (half) / _7 (bright)
        return percent < 34 ? 0xF00DE : percent < 67 ? 0xF00DF : 0xF00E0;
    }

    function detect(): void {
        const dev = Config.brightness?.device ?? "";
        info.command = dev !== "" ? ["brightnessctl", "-m", "-d", dev, "info"] : ["brightnessctl", "-m", "-c", "backlight", "info"];
        info.running = true;
    }

    Component.onCompleted: detect()

    // "intel_backlight,backlight,125,25%,504"
    Process {
        id: info
        stdout: StdioCollector {
            onStreamFinished: {
                const f = text.trim().split("\n")[0]?.split(",") ?? [];
                if (f.length < 5) {
                    console.warn("Brightness: no backlight device found");
                    return;
                }
                root.device = f[0];
                root.max = Number(f[4]);
                root.raw = Number(f[2]);
            }
        }
    }

    Connections {
        target: Config
        function onBrightnessChanged(): void {
            const dev = Config.brightness?.device ?? "";
            if (dev !== "" && dev !== root.device)
                root.detect();
        }
    }

    Timer {
        id: writeTimer
        interval: 40
        onTriggered: {
            if (root.pendingRaw < 0)
                return;
            Quickshell.execDetached(["brightnessctl", "-q", "-d", root.device, "set", String(root.pendingRaw)]);
            root.pendingRaw = -1;
            pollTimer.restart(); // don't read back a stale value mid-write
        }
    }

    // Catch changes from Fn keys / other tools. sysfs doesn't emit inotify, so poll.
    FileView {
        id: file
        path: root.available ? `/sys/class/backlight/${root.device}/brightness` : ""
        printErrors: false
        onLoaded: {
            const v = Number(text());
            if (!isNaN(v) && root.pendingRaw < 0 && !writeTimer.running)
                root.raw = v;
        }
    }

    Timer {
        id: pollTimer
        interval: 1500
        running: root.available
        repeat: true
        onTriggered: file.reload()
    }

    IpcHandler {
        target: "brightness"

        function up(): void {
            root.up();
        }
        function down(): void {
            root.down();
        }
        function set(percent: int): void {
            root.setPercent(percent);
        }
        function get(): int {
            return root.percent;
        }
    }
}
