import QtQuick
import qs.core
import qs.theme

// Base for every bar module. Children go inside; click opens the module's panel (if any).
MouseArea {
    id: root

    property string moduleId
    property var barScreen
    property var pill            // owning Pill; panels anchor to it
    property bool hoverHighlight: true
    property bool shown: true    // use this, not `visible`, to hide a module (the pill collapses around it)
    default property alias content: inner.data

    signal leftClicked
    signal rightClicked

    implicitWidth: inner.childrenRect.width + 2 * Theme.itemPadding
    implicitHeight: Theme.barHeight - 2 * Theme.borderWidth
    hoverEnabled: true
    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
    cursorShape: Qt.PointingHandCursor

    onClicked: mouse => {
        if (mouse.button === Qt.RightButton) {
            rightClicked();
            return;
        }
        leftClicked();
        const panel = Registry.panelForModule(moduleId);
        if (panel !== "")
            PanelManager.toggle(panel, "bar", root.pill);
    }

    Rectangle {
        anchors.fill: parent
        anchors.margins: 2
        radius: height / 2
        color: root.hoverHighlight && root.containsMouse ? Theme.surfaceHover : "transparent"

        Behavior on color {
            ColorAnimation {
                duration: Anim.fast
            }
        }
    }

    Item {
        id: inner
        anchors.centerIn: parent
        width: childrenRect.width
        height: childrenRect.height
    }
}
