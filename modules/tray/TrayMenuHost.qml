import QtQuick
import Quickshell
import qs.core
import qs.modules.tray

// Two TrayMenu windows that take turns, like the two PanelSlots in OverlayWindow:
// switching to another tray item's menu rolls the old one up under its icon while
// the new one unrolls under the other, both at once. Never reuse one window for the
// new item, or the content swaps instantly with no animation.
Scope {
    id: root

    property var screen
    property var barWindow

    readonly property TrayMenu cur: useB ? menuB : menuA
    property bool useB: false

    function isOpenFor(item: var): bool {
        return cur.shown && cur.trayItem === item;
    }

    // Menu to roll up once the new one can unroll. The new menu waits for its
    // entries over D-Bus, so closing the old one right away would run the two
    // animations one after the other instead of together.
    property TrayMenu pendingClose: null

    function open(item: var, anchorItem: Item): void {
        // Only one thing hangs off the bar at a time: close any open panel.
        PanelManager.close();
        if (cur.shown) {
            flushPending();
            pendingClose = cur;
            useB = !useB;
        }
        cur.open(item, anchorItem);
        if (cur.ready)
            flushPending();
        else if (pendingClose)
            pendingTimeout.restart();
    }

    function flushPending(): void {
        pendingTimeout.stop();
        if (pendingClose)
            pendingClose.close();
        pendingClose = null;
    }

    Connections {
        target: root.cur
        function onReadyChanged(): void {
            if (root.cur.ready)
                root.flushPending();
        }
    }

    // An app whose menu never fills in must not keep the old menu up.
    Timer {
        id: pendingTimeout
        interval: 300
        onTriggered: root.flushPending()
    }

    function close(): void {
        flushPending();
        cur.close();
    }

    function toggle(item: var, anchorItem: Item): void {
        isOpenFor(item) ? close() : open(item, anchorItem);
    }

    TrayMenu {
        id: menuA
        screen: root.screen
        barWindow: root.barWindow
    }

    TrayMenu {
        id: menuB
        screen: root.screen
        barWindow: root.barWindow
    }
}
