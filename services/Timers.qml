pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Countdown timers, a stopwatch and time-of-day alarms.
// State persists in Quickshell.statePath("timers.json"). Running timers store their
// END timestamp (not a remaining counter), so they survive reloads and restarts.
// On finish: notify-send (app "Timers") + pw-play.
//
// IPC: qs -c myshell ipc call timers start 300
//      ... startNamed "Tea" 180 | cancelAll | toggleStopwatch
Singleton {
    id: root

    readonly property string sound: "/usr/share/sounds/freedesktop/stereo/alarm-clock-elapsed.oga"
    readonly property var presets: [60, 300, 600, 1500]

    // timer: { id, name, duration (ms), state: "running"|"paused"|"done", endAt (ms epoch, running), remaining (ms, paused) }
    property var timers: []
    // { running, startedAt (ms epoch), accumulated (ms) }
    property var stopwatch: ({
            running: false,
            startedAt: 0,
            accumulated: 0
        })
    // alarm: { id, name, hour, minute, daily, enabled, nextAt (ms epoch) }
    property var alarms: []

    property real now: Date.now()
    property bool loaded: false

    // UI that shows a live stopwatch calls retain()/release() for a 10 Hz tick.
    property int consumers: 0
    function retain(): void {
        consumers++;
    }
    function release(): void {
        consumers = Math.max(0, consumers - 1);
    }

    readonly property var runningTimers: timers.filter(t => t.state === "running")
    readonly property bool anyRunning: runningTimers.length > 0
    // Soonest running timer: { id, name, remaining (ms), text } or null.
    readonly property var nextTimer: {
        let best = null;
        for (const t of runningTimers)
            if (!best || t.endAt < best.endAt)
                best = t;
        if (!best)
            return null;
        const rem = Math.max(0, best.endAt - now);
        return {
            id: best.id,
            name: best.name,
            remaining: rem,
            text: formatDuration(rem)
        };
    }
    readonly property string nextTimerText: nextTimer ? nextTimer.text : ""
    readonly property real stopwatchElapsed: stopwatch.accumulated + (stopwatch.running ? now - stopwatch.startedAt : 0)
    readonly property var nextAlarm: {
        let best = null;
        for (const a of alarms)
            if (a.enabled && (!best || a.nextAt < best.nextAt))
                best = a;
        return best;
    }

    // --- formatting / parsing ----------------------------------------------
    function formatDuration(ms: real): string {
        const s = Math.ceil(ms / 1000);
        const h = Math.floor(s / 3600);
        const m = Math.floor((s % 3600) / 60);
        const sec = s % 60;
        const pad = n => String(n).padStart(2, "0");
        return h > 0 ? `${h}:${pad(m)}:${pad(sec)}` : `${pad(m)}:${pad(sec)}`;
    }

    function formatStopwatch(ms: real): string {
        const tenths = Math.floor(ms / 100) % 10;
        const s = Math.floor(ms / 1000);
        const h = Math.floor(s / 3600);
        const m = Math.floor((s % 3600) / 60);
        const pad = n => String(n).padStart(2, "0");
        return (h > 0 ? h + ":" : "") + `${pad(m)}:${pad(s % 60)}.${tenths}`;
    }

    function presetLabel(sec: int): string {
        return sec >= 3600 ? sec / 3600 + "h" : sec >= 60 ? sec / 60 + "m" : sec + "s";
    }

    function formatClock(hour: int, minute: int): string {
        return String(hour).padStart(2, "0") + ":" + String(minute).padStart(2, "0");
    }

    // "90" = 90 min, "90s", "5m", "1h30m", "1h 30", "1:30" (m:s), "1:30:00" (h:m:s). Returns seconds or 0.
    function parseDuration(str: string): int {
        const s = (str ?? "").trim().toLowerCase();
        if (s === "")
            return 0;
        if (/^\d+(:\d{1,2}){1,2}$/.test(s)) {
            const p = s.split(":").map(Number);
            return p.length === 2 ? p[0] * 60 + p[1] : p[0] * 3600 + p[1] * 60 + p[2];
        }
        if (/^\d+(\.\d+)?$/.test(s))
            return Math.round(Number(s) * 60);
        const re = /(\d+(?:\.\d+)?)\s*(h|m|s)?/g;
        let total = 0;
        let matched = "";
        let m;
        let lastUnit = "";
        while ((m = re.exec(s)) !== null) {
            const n = Number(m[1]);
            const unit = m[2] ?? (lastUnit === "h" ? "m" : lastUnit === "m" ? "s" : "m");
            total += unit === "h" ? n * 3600 : unit === "m" ? n * 60 : n;
            lastUnit = unit;
            matched += m[0];
        }
        if (matched.replace(/\s/g, "") !== s.replace(/\s/g, ""))
            return 0;
        return Math.round(total);
    }

    // "7:30", "07:30", "730", "19" → { hour, minute } or null
    function parseClock(str: string): var {
        const s = (str ?? "").trim();
        let m = s.match(/^(\d{1,2})(?::|\.|h)?(\d{2})?$/);
        if (!m)
            return null;
        const hour = Number(m[1]);
        const minute = Number(m[2] ?? 0);
        if (hour > 23 || minute > 59)
            return null;
        return {
            hour,
            minute
        };
    }

    // --- timers ----------------------------------------------------------------
    function newId(): string {
        return Date.now().toString(36) + Math.random().toString(36).slice(2, 6);
    }

    function start(seconds: int, name: string): void {
        if (!(seconds > 0))
            return;
        const ms = seconds * 1000;
        const n = (name ?? "").trim();
        const list = timers.slice();
        // Refresh `now` first: the tick is stopped while nothing runs, so `now` can be
        // stale and the new timer would briefly show extra time until the next tick.
        now = Date.now();
        list.push({
            id: newId(),
            name: n !== "" ? n : formatDuration(ms) + " timer",
            duration: ms,
            state: "running",
            endAt: now + ms,
            remaining: ms
        });
        timers = list;
        changed();
    }

    function update(id: string, fn: var): void {
        now = Date.now();   // see start(): resume/restart would otherwise read a stale `now`
        timers = timers.map(t => t.id === id ? fn(Object.assign({}, t)) : t);
        changed();
    }

    function pause(id: string): void {
        update(id, t => {
            if (t.state === "running") {
                t.remaining = Math.max(0, t.endAt - Date.now());
                t.state = "paused";
            }
            return t;
        });
    }

    function resume(id: string): void {
        update(id, t => {
            if (t.state === "paused") {
                t.endAt = Date.now() + t.remaining;
                t.state = "running";
            }
            return t;
        });
    }

    function restart(id: string): void {
        update(id, t => {
            t.endAt = Date.now() + t.duration;
            t.remaining = t.duration;
            t.state = "running";
            return t;
        });
    }

    function cancel(id: string): void {
        timers = timers.filter(t => t.id !== id);
        changed();
    }

    function cancelAll(): void {
        timers = [];
        changed();
    }

    function clearDone(): void {
        timers = timers.filter(t => t.state !== "done");
        changed();
    }

    // --- stopwatch ---------------------------------------------------------
    function toggleStopwatch(): void {
        const t = Date.now();
        if (stopwatch.running)
            stopwatch = {
                running: false,
                startedAt: 0,
                accumulated: stopwatch.accumulated + t - stopwatch.startedAt
            };
        else
            stopwatch = {
                running: true,
                startedAt: t,
                accumulated: stopwatch.accumulated
            };
        now = t;
        changed();
    }

    function resetStopwatch(): void {
        stopwatch = {
            running: false,
            startedAt: 0,
            accumulated: 0
        };
        changed();
    }

    // --- alarms --------------------------------------------------------------
    function nextOccurrence(hour: int, minute: int, after: real): real {
        const d = new Date(after);
        d.setSeconds(0, 0);
        d.setHours(hour, minute);
        if (d.getTime() <= after)
            d.setDate(d.getDate() + 1);
        return d.getTime();
    }

    function addAlarm(hour: int, minute: int, daily: bool, name: string): void {
        const list = alarms.slice();
        list.push({
            id: newId(),
            name: (name ?? "").trim(),
            hour,
            minute,
            daily,
            enabled: true,
            nextAt: nextOccurrence(hour, minute, Date.now())
        });
        list.sort((a, b) => a.hour * 60 + a.minute - (b.hour * 60 + b.minute));
        alarms = list;
        changed();
    }

    function updateAlarm(id: string, fn: var): void {
        alarms = alarms.map(a => a.id === id ? fn(Object.assign({}, a)) : a);
        changed();
    }

    function setAlarmEnabled(id: string, on: bool): void {
        updateAlarm(id, a => {
            a.enabled = on;
            if (on)
                a.nextAt = nextOccurrence(a.hour, a.minute, Date.now());
            return a;
        });
    }

    function setAlarmDaily(id: string, daily: bool): void {
        updateAlarm(id, a => {
            a.daily = daily;
            return a;
        });
    }

    function removeAlarm(id: string): void {
        alarms = alarms.filter(a => a.id !== id);
        changed();
    }

    // --- engine ------------------------------------------------------------------
    function ring(title: string, body: string, critical: bool): void {
        Quickshell.execDetached(["notify-send", "-a", "Timers", "-i", "alarm-symbolic", "-u", critical ? "critical" : "normal", title, body]);
        Quickshell.execDetached(["pw-play", sound]);
    }

    // Fires finished timers and due alarms; reschedules the alarm check.
    function check(): void {
        const t = Date.now();
        now = t;
        let dirty = false;

        const list = timers.map(x => {
            if (x.state === "running" && x.endAt <= t) {
                ring("Timer finished", x.name + " (" + formatDuration(x.duration) + ")", false);
                dirty = true;
                return Object.assign({}, x, {
                    state: "done",
                    remaining: 0
                });
            }
            return x;
        });

        const al = alarms.map(a => {
            if (a.enabled && a.nextAt <= t) {
                dirty = true;
                // Fired late (suspend/shell down) by more than an hour: say so.
                const late = t - a.nextAt > 3600000;
                ring(late ? "Missed alarm" : "Alarm", (a.name !== "" ? a.name + " · " : "") + formatClock(a.hour, a.minute), true);
                return Object.assign({}, a, a.daily ? {
                    nextAt: nextOccurrence(a.hour, a.minute, t)
                } : {
                    enabled: false
                });
            }
            return a;
        });

        if (dirty) {
            timers = list;
            alarms = al;
            changed();
        }
        scheduleAlarm();
    }

    function scheduleAlarm(): void {
        if (!nextAlarm) {
            alarmTimer.stop();
            return;
        }
        // Re-check at most every 30 s so suspend/clock changes are caught quickly.
        alarmTimer.interval = Math.max(200, Math.min(30000, nextAlarm.nextAt - Date.now() + 50));
        alarmTimer.restart();
    }

    // Seconds tick while timers run (10 Hz while a stopwatch is on screen).
    Timer {
        id: tick
        interval: root.stopwatch.running && root.consumers > 0 ? 100 : 1000
        running: root.anyRunning || root.stopwatch.running
        repeat: true
        onTriggered: {
            root.now = Date.now();
            if (root.runningTimers.some(t => t.endAt <= root.now))
                root.check();
        }
    }

    Timer {
        id: alarmTimer
        repeat: false
        onTriggered: root.check()
    }

    // --- persistence ---------------------------------------------------------
    function changed(): void {
        if (!loaded)
            return;
        store.setText(JSON.stringify({
            timers,
            stopwatch,
            alarms
        }, null, 2));
        scheduleAlarm();
    }

    FileView {
        id: store
        path: Quickshell.statePath("timers.json")
        blockLoading: true
        printErrors: false
        onLoaded: {
            try {
                const d = JSON.parse(text());
                root.timers = Array.isArray(d.timers) ? d.timers : [];
                root.alarms = Array.isArray(d.alarms) ? d.alarms : [];
                if (d.stopwatch)
                    root.stopwatch = d.stopwatch;
            } catch (e) {
                console.warn("Timers: bad state file:", e);
            }
            root.finishLoad();
        }
        onLoadFailed: root.finishLoad()
    }

    function finishLoad(): void {
        if (loaded)
            return;
        loaded = true;
        check();    // timers that ended / alarms that passed while the shell was down
    }

    IpcHandler {
        target: "timers"

        function start(seconds: int): void {
            root.start(seconds, "");
        }
        function startNamed(name: string, seconds: int): void {
            root.start(seconds, name);
        }
        function cancelAll(): void {
            root.cancelAll();
        }
        function toggleStopwatch(): void {
            root.toggleStopwatch();
        }
        function next(): string {
            return root.nextTimer ? root.nextTimer.name + " " + root.nextTimer.text : "";
        }
    }
}
