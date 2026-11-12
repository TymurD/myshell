import QtQuick
import qs.modules.timers
import qs.components
import qs.theme

// Round icon-only action button.
MouseArea {
    id: root

    property int icon: 0
    property bool highlighted: false
    property color iconColor: highlighted ? Theme.bgSolid : Theme.text

    implicitWidth: 30
    implicitHeight: 30
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: root.highlighted ? Theme.accent : root.containsMouse ? Theme.surfaceHover : "transparent"
        border.color: root.highlighted ? Theme.accent : Theme.border
        border.width: Theme.borderWidth
        Behavior on color {
            ColorAnimation {
                duration: Anim.fast
            }
        }
    }
    Icon {
        anchors.centerIn: parent
        code: root.icon
        color: root.iconColor
        font.pixelSize: Theme.fontSizeSmall + 2
    }
}
