pragma Singleton

import QtQuick
import Quickshell

Singleton {
    id: root

    // Pushed from the clock instead of bound to it: a binding to `clock.date`
    // briefly evaluated to undefined during hot reloads and logged a warning.
    property date now: new Date()

    function format(fmt: string): string {
        return Qt.formatDateTime(now, fmt);
    }

    SystemClock {
        precision: SystemClock.Seconds
        onDateChanged: root.now = date
    }
}
