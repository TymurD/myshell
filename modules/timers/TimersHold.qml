import QtQuick
import qs.modules.timers
import qs.services

// While active, lets the Timers service tick fast enough for a live stopwatch.
QtObject {
    property bool active: false
    property bool _held: false
    function sync(): void {
        if (active && !_held) {
            Timers.retain();
            _held = true;
        } else if (!active && _held) {
            Timers.release();
            _held = false;
        }
    }
    onActiveChanged: sync()
    Component.onCompleted: sync()
    Component.onDestruction: {
        if (_held)
            Timers.release();
    }
}
