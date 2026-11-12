pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// CPU / memory / temperature / GPU stats.
// Polls ONLY while something consumes the data: UI calls retain() when it becomes
// visible and release() when it hides (see modules/sysstats/StatCard.qml).
//
// NVIDIA: calling nvidia-smi wakes the dGPU, so it is only queried while the PCI
// device is already runtime-"active", and at most every `gpuInterval` ms (longer than
// the driver's idle timeout, so our own queries don't keep it awake).
//
// settings.json → sysstats: { interval, gpuInterval, dgpuPci, historyLength }
Singleton {
    id: root

    // --- consumers -------------------------------------------------------
    property int consumers: 0
    readonly property bool active: consumers > 0

    function retain(): void {
        consumers++;
    }
    function release(): void {
        consumers = Math.max(0, consumers - 1);
    }

    readonly property int interval: Config.sysstats?.interval ?? 2000
    readonly property int gpuInterval: Config.sysstats?.gpuInterval ?? 10000
    readonly property string dgpuPci: Config.sysstats?.dgpuPci ?? "0000:01:00.0"
    readonly property int historyLength: Config.sysstats?.historyLength ?? 30

    // --- CPU -------------------------------------------------------------
    property real cpuUsage: 0           // 0..100
    property var cpuCores: []           // [0..100] per logical core
    property var cpuHistory: []
    property real cpuFreqGHz: 0         // average current frequency
    property real cpuFreqMaxGHz: 0      // fastest core right now
    property var _prevCpu: []           // [{ total, idle }] index 0 = aggregate

    // --- memory (kB) -----------------------------------------------------
    property real memTotal: 0
    property real memUsed: 0
    property real swapTotal: 0
    property real swapUsed: 0
    readonly property real memPercent: memTotal > 0 ? memUsed / memTotal * 100 : 0
    readonly property real swapPercent: swapTotal > 0 ? swapUsed / swapTotal * 100 : 0
    property var memHistory: []

    // --- temperatures (°C) -----------------------------------------------
    // [{ id, title, path, value }]: resolved by hwmon *name*, not index.
    property var temps: []
    property real cpuTemp: NaN
    property var cpuTempHistory: []

    // --- GPU -------------------------------------------------------------
    property string dgpuStatus: ""      // runtime PM status: "active" | "suspended" | ...
    readonly property bool dgpuPresent: dgpuStatus !== ""
    readonly property bool dgpuAwake: dgpuStatus === "active"
    property string dgpuName: "NVIDIA GPU"
    property bool dgpuHasData: false
    property real dgpuUtil: 0
    property real dgpuMemUsed: 0        // MiB
    property real dgpuMemTotal: 0       // MiB
    property real dgpuTemp: NaN
    property real dgpuPower: NaN        // W
    property var dgpuHistory: []
    property real _lastGpuQuery: 0

    property string igpuPath: ""        // /sys/class/drm/cardN (i915)
    property real igpuFreq: 0           // MHz
    property real igpuMaxFreq: 0
    readonly property real igpuPercent: igpuMaxFreq > 0 ? igpuFreq / igpuMaxFreq * 100 : 0
    property var igpuHistory: []

    // --- helpers ---------------------------------------------------------
    function pushHistory(arr: var, v: real): var {
        const out = arr.slice(Math.max(0, arr.length - historyLength + 1));
        out.push(v);
        return out;
    }

    function formatKb(kb: real): string {
        const gib = kb / 1048576;
        return gib >= 10 ? gib.toFixed(0) + " GiB" : gib.toFixed(1) + " GiB";
    }

    function formatTemp(t: real): string {
        return isNaN(t) ? "—" : Math.round(t) + "°C";
    }

    // --- polling ---------------------------------------------------------
    Timer {
        interval: root.interval
        running: root.active
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            statFile.reload();
            memFile.reload();
            cpuinfoFile.reload();
            dgpuStatusFile.reload();
            for (let i = 0; i < tempFiles.count; i++)
                tempFiles.objectAt(i)?.reload();
            if (root.igpuPath !== "")
                igpuFreqFile.reload();
        }
    }

    onActiveChanged: {
        if (active && !discover.ran)
            discover.running = true;
    }

    FileView {
        id: statFile
        path: "/proc/stat"
        printErrors: false
        onLoaded: root.parseStat(text())
    }

    function parseStat(txt: string): void {
        const lines = txt.split("\n");
        const prev = _prevCpu;
        const next = [];
        const cores = [];
        let total = 0;
        for (const line of lines) {
            if (!line.startsWith("cpu"))
                break;
            const f = line.trim().split(/\s+/);
            const v = f.slice(1, 9).map(Number);
            const sum = v.reduce((a, b) => a + b, 0);
            const idle = v[3] + v[4];
            const i = next.length;
            next.push({
                total: sum,
                idle: idle
            });
            let pct = 0;
            if (prev[i]) {
                const dt = sum - prev[i].total;
                pct = dt > 0 ? Math.max(0, Math.min(100, (1 - (idle - prev[i].idle) / dt) * 100)) : 0;
            }
            if (i === 0)
                total = pct;
            else
                cores.push(pct);
        }
        const first = prev.length === 0;
        _prevCpu = next;
        if (first)
            return;
        cpuUsage = total;
        cpuCores = cores;
        cpuHistory = pushHistory(cpuHistory, total);
    }

    FileView {
        id: memFile
        path: "/proc/meminfo"
        printErrors: false
        onLoaded: {
            const m = {};
            for (const line of text().split("\n")) {
                const r = line.match(/^(\w+):\s+(\d+)/);
                if (r)
                    m[r[1]] = Number(r[2]);
            }
            root.memTotal = m.MemTotal ?? 0;
            root.memUsed = (m.MemTotal ?? 0) - (m.MemAvailable ?? 0);
            root.swapTotal = m.SwapTotal ?? 0;
            root.swapUsed = (m.SwapTotal ?? 0) - (m.SwapFree ?? 0);
            root.memHistory = root.pushHistory(root.memHistory, root.memPercent);
        }
    }

    FileView {
        id: cpuinfoFile
        path: "/proc/cpuinfo"
        printErrors: false
        onLoaded: {
            const mhz = text().match(/^cpu MHz\s*:\s*[\d.]+/gm) ?? [];
            if (mhz.length === 0)
                return;
            const vals = mhz.map(s => Number(s.split(":")[1]));
            root.cpuFreqGHz = vals.reduce((a, b) => a + b, 0) / vals.length / 1000;
            root.cpuFreqMaxGHz = Math.max(...vals) / 1000;
        }
    }

    // --- temps: discover hwmon sensors + iGPU once -------------------------
    Process {
        id: discover
        property bool ran: false
        command: ["sh", "-c", `
for h in /sys/class/hwmon/hwmon*; do
  n=$(cat "$h/name" 2>/dev/null)
  for i in "$h"/temp*_input; do
    [ -e "$i" ] || continue
    l=$(cat "\${i%_input}_label" 2>/dev/null)
    printf 'T\\t%s\\t%s\\t%s\\n' "$n" "$l" "$i"
  done
done
for c in /sys/class/drm/card*; do
  [ -e "$c/gt_cur_freq_mhz" ] && printf 'G\\t%s\\t%s\\n' "$c" "$(cat "$c/gt_max_freq_mhz")"
done
true`]
        onStarted: ran = true
        stdout: StdioCollector {
            onStreamFinished: root.parseDiscovery(text)
        }
    }

    // Which sensors to show, by hwmon name (+ label). First match per id wins.
    readonly property var sensorRules: [
        {
            id: "cpu",
            title: "CPU",
            match: [["coretemp", "Package id 0"], ["k10temp", "Tctl"], ["zenpower", "Tdie"], ["cpu_thermal", ""]]
        },
        {
            id: "acpi",
            title: "Board",
            match: [["acpitz", ""]]
        },
        {
            id: "nvme",
            title: "NVMe",
            match: [["nvme", "Composite"], ["nvme", ""]]
        },
        {
            id: "wifi",
            title: "Wi-Fi",
            match: [["iwlwifi_1", ""], ["iwlwifi", ""]]
        }
    ]

    function parseDiscovery(txt: string): void {
        const sensors = [];
        for (const line of txt.split("\n")) {
            const f = line.split("\t");
            if (f[0] === "T")
                sensors.push({
                    name: f[1],
                    label: f[2],
                    path: f[3]
                });
            else if (f[0] === "G" && igpuPath === "") {
                igpuPath = f[1];
                igpuMaxFreq = Number(f[2]) || 0;
            }
        }
        const out = [];
        for (const rule of sensorRules) {
            let hit = null;
            for (const [name, label] of rule.match) {
                hit = sensors.find(s => (s.name === name || s.name.startsWith(name + "_")) && (label === "" || s.label === label));
                if (hit)
                    break;
            }
            if (hit)
                out.push({
                    id: rule.id,
                    title: rule.title,
                    path: hit.path,
                    value: NaN
                });
        }
        temps = out;
    }

    Instantiator {
        id: tempFiles
        model: root.temps.length

        FileView {
            required property int index
            path: root.temps[index]?.path ?? ""
            printErrors: false
            onLoaded: root.setTemp(index, Number(text()) / 1000)
        }
    }

    function setTemp(i: int, v: real): void {
        const t = temps.slice();
        if (!t[i])
            return;
        t[i] = Object.assign({}, t[i], {
            value: v
        });
        temps = t;
        if (t[i].id === "cpu") {
            cpuTemp = v;
            cpuTempHistory = pushHistory(cpuTempHistory, v);
        }
    }

    // --- GPU -------------------------------------------------------------
    FileView {
        id: igpuFreqFile
        path: root.igpuPath !== "" ? root.igpuPath + "/gt_cur_freq_mhz" : ""
        printErrors: false
        onLoaded: {
            root.igpuFreq = Number(text()) || 0;
            root.igpuHistory = root.pushHistory(root.igpuHistory, root.igpuPercent);
        }
    }

    FileView {
        id: dgpuStatusFile
        path: "/sys/bus/pci/devices/" + root.dgpuPci + "/power/runtime_status"
        printErrors: false
        onLoadFailed: root.dgpuStatus = ""
        onLoaded: {
            root.dgpuStatus = text().trim();
            if (!root.dgpuAwake) {
                root.dgpuHasData = false;
                root.dgpuHistory = root.pushHistory(root.dgpuHistory, 0);
                return;
            }
            // Only touch nvidia-smi while the card is already awake, and not so often
            // that our own queries keep it from runtime-suspending.
            const now = Date.now();
            if (!nvsmi.running && now - root._lastGpuQuery >= root.gpuInterval) {
                root._lastGpuQuery = now;
                nvsmi.running = true;
            }
        }
    }

    Process {
        id: nvsmi
        command: ["nvidia-smi", "--query-gpu=name,utilization.gpu,memory.used,memory.total,temperature.gpu,power.draw", "--format=csv,noheader,nounits"]
        stdout: StdioCollector {
            onStreamFinished: {
                const f = text.trim().split(",").map(s => s.trim());
                if (f.length < 6)
                    return;
                root.dgpuName = f[0].replace(/^NVIDIA (GeForce )?/, "");
                root.dgpuUtil = Number(f[1]) || 0;
                root.dgpuMemUsed = Number(f[2]) || 0;
                root.dgpuMemTotal = Number(f[3]) || 0;
                root.dgpuTemp = Number(f[4]);
                root.dgpuPower = Number(f[5]);
                root.dgpuHasData = true;
                root.dgpuHistory = root.pushHistory(root.dgpuHistory, root.dgpuUtil);
            }
        }
    }
}
