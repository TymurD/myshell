import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.components
import qs.core
import qs.theme
import qs.modules.tray

// Themed menu for a tray item's DBusMenu (replaces the native, unstyled menu).
// open(item, anchorItem) shows it under the icon; clicking outside, Esc or
// triggering an entry closes it.
//
// A layer surface, not a PopupWindow: while a HyprlandFocusGrab is active, Hyprland
// refuses pointer input to an xdg popup of a layer surface (whitelisting the popup or
// the bar doesn't help), so a popup menu drew but ignored hover and clicks. On the
// overlay layer it behaves like the panels in OverlayWindow, grab included.
PanelWindow {
    id: root

    property var barWindow       // whitelisted in the grab, like the panel grab
    property var trayItem: null
    property bool shown: false
    property real centerX: 0     // icon centre, in screen coordinates

    function open(item: var, anchorItem: Item): void {
        trayItem = item;
        centerX = anchorItem.mapToItem(null, anchorItem.width / 2, 0).x;
        shown = true;
    }
    function close(): void {
        shown = false;
    }

    readonly property int pad: 6
    implicitWidth: Math.max(220, list.implicitWidth) + 2 * pad
    implicitHeight: list.implicitHeight + 2 * pad

    // Hangs under the icon, centred, at the same gap below the bar as panels,
    // kept inside the screen edges.
    anchors {
        top: true
        left: true
    }
    exclusionMode: ExclusionMode.Ignore
    margins.top: Theme.barMargin + Theme.barHeight + Theme.panelGap
    margins.left: Math.max(Theme.barMargin, Math.min(centerX - implicitWidth / 2, (screen?.width ?? 0) - implicitWidth - Theme.barMargin))

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "myshell-traymenu"
    // Only while shown: during a swap the menu rolling up must not keep the keyboard
    // from the one unrolling. Constant while open, so the grab isn't dropped.
    WlrLayershell.keyboardFocus: shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    // Entries have arrived (the list is empty for a moment after open); until then
    // there is nothing to unroll.
    // Counted, not measured: reading a Column's implicitHeight lays it out on the
    // spot, which changed it mid-evaluation (binding loop on `visible`).
    readonly property bool ready: trayItem !== null && list.count > 0

    // Open progress 0..1, like PanelSlot.t for a bar-opened panel: unrolls down from a
    // bar-high capsule in bar colour, content fades in late; rolls back up on close.
    // The window stays mapped until the roll-up has finished.
    property real t: shown && ready ? 1 : 0
    Behavior on t {
        NumberAnimation {
            duration: root.shown ? Anim.slow : Anim.normal
            easing.type: root.shown ? Anim.standard : Anim.exit
        }
    }

    function lerp(a: real, b: real, k: real): real {
        return a + (b - a) * k;
    }

    visible: ready && (shown || t > 0)
    color: "transparent"
    // Input only where the menu is drawn so far.
    mask: Region {
        item: surface
    }

    // Same shape as the panel grab in OverlayWindow: arm only once fully open, and
    // whitelist the bar, so clicking the tray icon toggles the menu instead of the
    // grab closing it on press and the click reopening it.
    HyprlandFocusGrab {
        active: root.visible && root.backingWindowVisible && root.shown && root.t >= 1
        windows: [root, root.barWindow]
        onCleared: root.close()
    }

    Connections {
        target: PanelManager
        function onDismissRequested(): void {
            root.close();
        }
        // A bar button opened a panel while the menu was up.
        function onOpenIdChanged(): void {
            if (PanelManager.openId !== "")
                root.close();
        }
    }

    Item {
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: root.close()
    }

    PanelSurface {
        id: surface

        readonly property real startH: Math.min(Theme.barHeight, root.height)

        width: root.width
        height: root.lerp(startH, root.height, root.t)
        radius: root.lerp(startH / 2, Theme.radius - 4, root.t)
        color: Qt.rgba(root.lerp(Theme.bg.r, Theme.bgPanel.r, root.t), root.lerp(Theme.bg.g, Theme.bgPanel.g, root.t), root.lerp(Theme.bg.b, Theme.bgPanel.b, root.t), root.lerp(Theme.bg.a, Theme.bgPanel.a, root.t))
        opacity: Math.min(1, root.t * 4)
        clip: true

        TrayMenuList {
            id: list
            x: root.pad
            y: root.pad
            // Fixed size while the surface grows around it, so nothing reflows.
            width: root.width - 2 * root.pad
            opacity: Math.max(0, Math.min(1, (root.t - 0.15) / 0.5))
            handle: root.trayItem?.menu ?? null
            onTriggered: root.close()
        }
    }
}
