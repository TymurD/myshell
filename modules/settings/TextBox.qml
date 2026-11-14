import QtQuick
import qs.modules.settings
import qs.components
import qs.theme

// Single-line input with placeholder. Enter emits accepted().
Rectangle {
    id: root

    property alias text: input.text
    property string placeholder
    signal accepted

    function clear(): void {
        input.text = "";
    }

    implicitWidth: 120
    implicitHeight: 30
    radius: Theme.radiusSmall
    color: Theme.surface
    border.color: input.activeFocus ? Theme.borderStrong : Theme.border
    border.width: Theme.borderWidth

    TextInput {
        id: input
        anchors.fill: parent
        anchors.leftMargin: 10
        anchors.rightMargin: 10
        verticalAlignment: TextInput.AlignVCenter
        color: Theme.text
        selectionColor: Theme.accent
        selectedTextColor: Theme.bgSolid
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeSmall
        clip: true
        onAccepted: root.accepted()
        Keys.onEscapePressed: event => {
            if (text !== "") {
                text = "";
                event.accepted = true;
            } else {
                focus = false;
                event.accepted = false;
            }
        }
    }
    StyledText {
        anchors.fill: input
        visible: input.text === "" && !input.activeFocus
        text: root.placeholder
        color: Theme.textMuted
        font.pixelSize: Theme.fontSizeSmall
    }
}
