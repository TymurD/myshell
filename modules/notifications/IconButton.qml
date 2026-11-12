import QtQuick
import qs.components
import qs.theme

// Small round glyph button (close, mute, collapse, ...).
MouseArea {
    id: root

    property int code
    property color color: Theme.textDim
    property bool active: false   // filled look, e.g. DND on
    property string label: ""     // optional text after the glyph

    implicitWidth: label === "" ? glyph.implicitHeight + 8 : row.implicitWidth + 2 * Theme.radiusSmall + 4
    implicitHeight: glyph.implicitHeight + 8
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor

    Behavior on opacity {
        NumberAnimation {
            duration: Anim.fast
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: root.active ? Theme.accent : root.containsMouse ? Theme.surfaceHover : "transparent"
        border.color: root.label !== "" && !root.active ? Theme.border : "transparent"
        border.width: Theme.borderWidth

        Behavior on color {
            ColorAnimation {
                duration: Anim.fast
            }
        }
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 6

        Icon {
            id: glyph
            anchors.verticalCenter: parent.verticalCenter
            code: root.code
            font.pixelSize: Theme.fontSizeSmall + 2
            color: root.active ? Theme.bgSolid : root.containsMouse ? Theme.text : root.color
        }
        StyledText {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.label !== ""
            text: root.label
            font.pixelSize: Theme.fontSizeSmall
            color: root.active ? Theme.bgSolid : Theme.text
        }
    }
}
