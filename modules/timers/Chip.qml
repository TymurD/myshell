import QtQuick
import qs.modules.timers
import qs.components
import qs.theme

// Small text button; `checked` fills it with the accent.
MouseArea {
    id: root

    property string text
    property bool checked: false

    implicitWidth: label.implicitWidth + 2 * 12
    implicitHeight: 28
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: root.checked ? Theme.accent : root.containsMouse ? Theme.surfaceHover : Theme.surface
        border.color: root.checked ? Theme.accent : Theme.border
        border.width: Theme.borderWidth
        Behavior on color {
            ColorAnimation {
                duration: Anim.fast
            }
        }
    }
    StyledText {
        id: label
        anchors.centerIn: parent
        text: root.text
        font.pixelSize: Theme.fontSizeSmall
        color: root.checked ? Theme.bgSolid : Theme.text
    }
}
