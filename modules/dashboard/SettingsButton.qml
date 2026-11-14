import QtQuick
import qs.modules.dashboard
import qs.components
import qs.theme

// Gear in the dashboard header; opens the settings panel in the dashboard's spot.
MouseArea {
    id: root

    implicitWidth: Theme.barHeight * 0.9
    implicitHeight: Theme.barHeight * 0.9
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: root.containsMouse ? Theme.surfaceHover : "transparent"
        border.color: Theme.border
        border.width: Theme.borderWidth
        Behavior on color {
            ColorAnimation {
                duration: Anim.fast
            }
        }
    }
    Icon {
        anchors.centerIn: parent
        code: 0xF0493 // nf-md-cog
        color: root.containsMouse ? Theme.text : Theme.textDim
        font.pixelSize: Theme.fontSizeSmall + 2
    }
}
