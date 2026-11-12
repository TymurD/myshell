pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Session actions: lock, logout, suspend, reboot, shutdown.
// The QS lock screen (modules/lock) listens to `lockRequested`.
// settings.json:
//   lock.useQuickshell (default true)  false → run lock.command instead (e.g. "hyprlock")
//   lock.command       (default "hyprlock")
//   session.dryRun     (default false) only log the commands, never run them
//   session.lockBeforeSuspend (default true)
//   session.confirmTimeout (ms, default 3000) how long an armed button stays armed
Singleton {
    id: root

    // Runtime override for testing (`qs ipc call session dryrun true`); null = use settings.
    property var dryRunOverride: null
    readonly property bool dryRun: dryRunOverride ?? (Config.session?.dryRun ?? false)
    readonly property bool useQuickshellLock: Config.lock?.useQuickshell ?? true
    readonly property string lockCommand: Config.lock?.command ?? "hyprlock"
    readonly property bool lockBeforeSuspend: Config.session?.lockBeforeSuspend ?? true
    readonly property int confirmTimeout: Config.session?.confirmTimeout ?? 3000

    // Set by the lock screen while a real session lock is held.
    property bool locked: false

    // The QS lock screen reacts to these.
    signal lockRequested
    signal lockPreviewRequested

    // Order = order in the session panel. `confirm`: needs a second click.
    readonly property var actions: [
        {
            id: "lock",
            name: "Lock",
            verb: "lock",
            icon: 0xF033E,
            confirm: false
        },
        {
            id: "logout",
            name: "Logout",
            verb: "log out",
            icon: 0xF0343,
            confirm: true
        },
        {
            id: "suspend",
            name: "Suspend",
            verb: "suspend",
            icon: 0xF04B2,
            confirm: false
        },
        {
            id: "reboot",
            name: "Reboot",
            verb: "reboot",
            icon: 0xF0709,
            confirm: true
        },
        {
            id: "shutdown",
            name: "Shutdown",
            verb: "shut down",
            icon: 0xF0425,
            confirm: true
        }
    ]

    function run(cmd: var): void {
        if (dryRun) {
            console.info("Session (dry run):", JSON.stringify(cmd));
            return;
        }
        Quickshell.execDetached(cmd);
    }

    function lock(): void {
        if (locked)
            return;
        if (!useQuickshellLock) {
            run(["sh", "-c", lockCommand]);
            return;
        }
        if (dryRun) {
            console.info("Session (dry run): lock");
            return;
        }
        lockRequested();
    }

    function previewLock(): void {
        lockPreviewRequested();
    }

    function logout(): void {
        // Hyprland Lua config: dispatchers are Lua expressions (hl.dsp.exit).
        run(["hyprctl", "dispatch", "hl.dsp.exit()"]);
    }

    function suspend(): void {
        if (lockBeforeSuspend)
            lock();
        run(["systemctl", "suspend"]);
    }

    function reboot(): void {
        run(["systemctl", "reboot"]);
    }

    function shutdown(): void {
        run(["systemctl", "poweroff"]);
    }

    function perform(id: string): void {
        switch (id) {
        case "lock":
            return lock();
        case "logout":
            return logout();
        case "suspend":
            return suspend();
        case "reboot":
            return reboot();
        case "shutdown":
            return shutdown();
        default:
            console.warn("Session: unknown action", id);
        }
    }

    IpcHandler {
        target: "session"

        function lock(): void {
            root.lock();
        }
        function logout(): void {
            root.logout();
        }
        function suspend(): void {
            root.suspend();
        }
        function reboot(): void {
            root.reboot();
        }
        function shutdown(): void {
            root.shutdown();
        }
        function dryrun(on: bool): void {
            root.dryRunOverride = on;
        }
    }
}
