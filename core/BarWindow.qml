import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.theme
import qs.components
import qs.core
// Bar modules are loaded by URL too; import folders whose files use siblings
// (see the note in OverlayWindow.qml).
import qs.modules.tray

// Top bar for one screen: three independent pills (left / center / right).
PanelWindow {
    id: root

    anchors {
        top: true
        left: true
        right: true
    }
    implicitHeight: Theme.barHeight + Theme.barMargin
    color: "transparent"
    WlrLayershell.namespace: "myshell-bar"

    // Empty bar space (between and around the pills) dismisses open panels/menus.
    // Declared before the pills so their buttons stay on top.
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
        onPressed: PanelManager.dismissAll()
    }

    // The panel focus grab whitelists the bar, and inside a grab Hyprland gives
    // keyboard focus to the whitelisted surface under the pointer. So with the cursor
    // over the bar, keys land here instead of in the overlay: handle Esc here too.
    Item {
        focus: true
        Keys.onEscapePressed: PanelManager.dismissAll()
    }

    Pill {
        anchors.left: parent.left
        anchors.leftMargin: Theme.barMargin
        anchors.top: parent.top
        anchors.topMargin: Theme.barMargin
        side: "left"
        modules: Config.bar.left ?? []
        barScreen: root.screen
    }

    Pill {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: Theme.barMargin
        side: "center"
        modules: Config.bar.center ?? []
        barScreen: root.screen
    }

    Pill {
        anchors.right: parent.right
        anchors.rightMargin: Theme.barMargin
        anchors.top: parent.top
        anchors.topMargin: Theme.barMargin
        side: "right"
        modules: Config.bar.right ?? []
        barScreen: root.screen
    }
}
