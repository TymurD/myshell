import QtQuick
import qs.components
import qs.services
import qs.theme

BarButton {
    hoverHighlight: false

    Row {
        spacing: 0

        Repeater {
            model: Workspaces.ids

            MouseArea {
                id: ws
                required property int modelData
                readonly property bool active: Workspaces.focusedId === modelData
                readonly property bool occupied: Workspaces.occupied(modelData)

                width: 26
                height: Theme.barHeight - 2 * Theme.borderWidth
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Workspaces.activate(modelData)

                StyledText {
                    anchors.centerIn: parent
                    text: "●"
                    font.pixelSize: ws.active ? Theme.fontSize : Theme.fontSizeSmall
                    color: ws.active ? Theme.text : ws.containsMouse ? Theme.textDim : ws.occupied ? Theme.textMuted : Theme.textFaint

                    Behavior on color {
                        ColorAnimation {
                            duration: Anim.fast
                        }
                    }
                }
            }
        }
    }
}
