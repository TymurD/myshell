pragma Singleton

import QtQuick
import Quickshell

Singleton {
    readonly property date now: clock?.date ?? new Date()

    function format(fmt: string): string {
        return Qt.formatDateTime(now, fmt);
    }

    SystemClock {
        id: clock
        precision: SystemClock.Seconds
    }
}
