import QtQuick
import Quickshell
import qs.config

// Harness for config/Config.qml, run by tests/config.sh in an isolated XDG_CONFIG_HOME.
// Prints "PASS <case>" or "FAIL <case>: <why>" and quits.
ShellRoot {
    id: root

    readonly property string mode: Quickshell.env("TEST_MODE") ?? ""
    property int barChanges: 0
    property bool counting: false

    function finish(ok: bool, why: string): void {
        console.warn(ok ? "PASS " + mode : "FAIL " + mode + ": " + why);
        Qt.quit();
    }

    Connections {
        target: Config
        function onBarChanged() {
            if (root.counting)
                root.barChanges++;
        }
    }

    // early-set: a set issued before the user file's first load must keep the
    // overrides already saved in it (on disk and in memory).
    Component.onCompleted: {
        if (mode === "early-set")
            Config.set("session.dryRun", true);
        if (mode === "missing-quiet")
            startCount.start();
    }

    Timer {
        running: root.mode === "early-set"
        interval: 2000
        onTriggered: {
            const ok = Config.palette === "mine" && JSON.stringify(Config.bar.left) === '["clock"]' && Config.session.dryRun === true;
            root.finish(ok, "memory palette=" + Config.palette + " bar.left=" + JSON.stringify(Config.bar.left) + " dryRun=" + Config.session.dryRun);
        }
    }

    // missing-quiet: with no user file, polling for it must not re-emit config changes.
    Timer {
        id: startCount
        interval: 1000
        onTriggered: {
            root.counting = true;
            stopCount.start();
        }
    }
    Timer {
        id: stopCount
        interval: 5000
        onTriggered: root.finish(root.barChanges === 0, "Config.bar changed " + root.barChanges + " times while the user file was missing")
    }
}
