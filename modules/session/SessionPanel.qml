import QtQuick
import qs.components
import qs.core
import qs.services
import qs.theme

// Lock / Logout / Suspend / Reboot / Shutdown. Destructive actions arm on the first
// click ("Click again to reboot") and run on the second; they disarm after a few seconds.
// Keyboard: ←/→ (or h/l, Tab) select, Enter/Space activate, 1-5 pick directly.
PanelSurface {
    id: root

    property string panelId
    property int selected: -1
    property string armed: ""

    readonly property int buttonSize: Theme.barHeight * 3
    readonly property var actions: Session.actions
    readonly property var armedAction: actions.find(a => a.id === armed) ?? null

    implicitWidth: row.implicitWidth + 2 * Theme.panelPadding
    implicitHeight: row.implicitHeight + status.implicitHeight + 3 * Theme.panelPadding - Theme.panelGap / 2

    function activate(i: int): void {
        const a = actions[i];
        if (!a)
            return;
        selected = i;
        if (a.confirm && armed !== a.id) {
            armed = a.id;
            disarm.restart();
            return;
        }
        armed = "";
        disarm.stop();
        PanelManager.close();
        Session.perform(a.id);
    }

    function move(d: int): void {
        selected = selected < 0 ? (d > 0 ? 0 : actions.length - 1) : (selected + d + actions.length) % actions.length;
        if (armed !== "" && actions[selected].id !== armed)
            armed = "";
    }

    Timer {
        id: disarm
        interval: Session.confirmTimeout
        onTriggered: root.armed = ""
    }

    Item {
        id: keys
        focus: true
        Component.onCompleted: forceActiveFocus()

        Keys.onPressed: event => {
            switch (event.key) {
            case Qt.Key_Left:
            case Qt.Key_H:
            case Qt.Key_Backtab:
                root.move(-1);
                break;
            case Qt.Key_Right:
            case Qt.Key_L:
            case Qt.Key_Tab:
                root.move(1);
                break;
            case Qt.Key_Return:
            case Qt.Key_Enter:
            case Qt.Key_Space:
                if (root.selected >= 0)
                    root.activate(root.selected);
                break;
            default:
                if (event.key >= Qt.Key_1 && event.key < Qt.Key_1 + root.actions.length)
                    root.activate(event.key - Qt.Key_1);
                else
                    return;
            }
            event.accepted = true;
        }
    }

    Row {
        id: row
        x: Theme.panelPadding
        y: Theme.panelPadding
        spacing: Theme.panelGap

        Repeater {
            model: root.actions

            MouseArea {
                id: btn
                required property var modelData
                required property int index
                readonly property bool isArmed: root.armed === modelData.id
                readonly property bool isSelected: root.selected === index
                readonly property bool hot: containsMouse || isSelected

                width: root.buttonSize
                height: root.buttonSize
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.activate(index)
                onContainsMouseChanged: if (containsMouse)
                    root.selected = index

                Rectangle {
                    anchors.fill: parent
                    radius: Theme.radius
                    color: btn.isArmed ? Theme.urgent : btn.hot ? Theme.surfaceHover : Theme.surface
                    border.width: Theme.borderWidth
                    border.color: btn.isArmed ? Theme.urgent : btn.isSelected ? Theme.borderStrong : Theme.border
                    scale: btn.pressed ? 0.96 : 1

                    Behavior on color {
                        ColorAnimation {
                            duration: Anim.fast
                        }
                    }
                    Behavior on scale {
                        NumberAnimation {
                            duration: Anim.fast
                            easing.type: Anim.standard
                        }
                    }
                }

                Column {
                    anchors.centerIn: parent
                    spacing: Theme.panelGap

                    Icon {
                        anchors.horizontalCenter: parent.horizontalCenter
                        code: btn.modelData.icon
                        font.pixelSize: Theme.fontSizeXL
                        color: btn.isArmed ? Theme.bgSolid : btn.hot ? Theme.text : Theme.textDim
                    }
                    StyledText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: btn.isArmed ? "Confirm" : btn.modelData.name
                        font.pixelSize: Theme.fontSizeSmall
                        color: btn.isArmed ? Theme.bgSolid : Theme.text
                    }
                }
            }
        }
    }

    StyledText {
        id: status
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: row.bottom
        anchors.topMargin: Theme.panelPadding - Theme.panelGap / 2
        text: root.armedAction ? "Click again to " + root.armedAction.verb : Session.dryRun ? "Dry run: actions are only logged" : root.selected >= 0 ? root.actions[root.selected].name : "Session"
        color: root.armedAction ? Theme.urgent : Theme.textDim
        font.pixelSize: Theme.fontSizeSmall
    }
}
