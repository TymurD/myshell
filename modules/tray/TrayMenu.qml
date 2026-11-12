import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.components
import qs.theme
import qs.modules.tray

// Themed popup for a tray item's DBusMenu (replaces the native, unstyled menu).
// open(item, anchorItem) shows it under the icon; clicking outside, Esc or
// triggering an entry closes it.
PopupWindow {
    id: root

    property var trayItem: null
    property bool shown: false

    function open(item: var, anchorItem: Item): void {
        trayItem = item;
        anchor.item = anchorItem;
        shown = true;
    }
    function close(): void {
        shown = false;
    }

    // A point under the icon's centre, at the same gap below the bar as panels use;
    // the popup hangs from it, centred, sliding to stay on screen.
    anchor.rect.x: (anchor.item?.width ?? 0) / 2
    anchor.rect.y: (anchor.item?.height ?? 0) / 2 + Theme.barHeight / 2 + Theme.panelGap
    anchor.rect.width: 1
    anchor.rect.height: 1
    anchor.edges: Edges.Top
    anchor.gravity: Edges.Bottom
    anchor.adjustment: PopupAdjustment.Slide

    implicitWidth: Math.max(220, list.implicitWidth) + 2 * pad
    implicitHeight: list.implicitHeight + 2 * pad
    readonly property int pad: 6
    visible: shown && trayItem !== null
    color: "transparent"

    HyprlandFocusGrab {
        active: root.visible
        windows: [root]
        onCleared: root.close()
    }

    PanelSurface {
        anchors.fill: parent
        radius: Theme.radius - 4

        Item {
            anchors.fill: parent
            focus: true
            Keys.onEscapePressed: root.close()
        }

        TrayMenuList {
            id: list
            x: root.pad
            y: root.pad
            width: root.width - 2 * root.pad
            handle: root.trayItem?.menu ?? null
            onTriggered: root.close()
        }
    }
}
