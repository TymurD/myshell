import QtQuick
import qs.components
import qs.theme

// Rounded search input with a magnifier icon. `input` is the TextInput, so
// callers can attach Keys handlers to it.
//
// Root is a FocusScope: callers set `focus: true` on the field and focus is
// forwarded to the TextInput inside. (With a plain Rectangle root, the outer
// `focus: true` and the input's own `focus: true` compete in the same scope and
// the Rectangle wins, so typing goes nowhere.)
FocusScope {
    id: root

    property alias text: input.text
    property alias input: input
    property string placeholder: "Search"
    property int iconCode: 0xF0349 // nf-md-magnify
    readonly property bool active: input.activeFocus

    // Clicked: the owning panel decides about focus (PanelManager.focus), so the
    // focus bindings in OverlayWindow are not broken by forceActiveFocus.
    signal activated
    // Every key press in the input, before the input handles it. Set
    // event.accepted = true to consume it.
    signal keyPressed(var event)

    implicitHeight: Theme.barHeight + Theme.panelGap

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: Theme.surface
        border.color: root.active ? Theme.borderStrong : Theme.border
        border.width: Theme.borderWidth

        Behavior on border.color {
            ColorAnimation {
                duration: Anim.fast
            }
        }
    }

    Icon {
        id: icon
        anchors.left: parent.left
        anchors.leftMargin: Theme.itemPadding
        anchors.verticalCenter: parent.verticalCenter
        code: root.iconCode
        color: root.active ? Theme.text : Theme.textDim
    }

    TextInput {
        id: input
        anchors.left: icon.right
        anchors.leftMargin: Theme.panelGap + 2
        anchors.right: parent.right
        anchors.rightMargin: Theme.itemPadding
        anchors.verticalCenter: parent.verticalCenter
        focus: true
        clip: true
        activeFocusOnPress: false
        Keys.priority: Keys.BeforeItem
        Keys.onPressed: event => {
            event.accepted = false;
            root.keyPressed(event);
        }
        color: Theme.text
        selectionColor: Theme.accent
        selectedTextColor: Theme.bgSolid
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize
        verticalAlignment: TextInput.AlignVCenter

        StyledText {
            anchors.fill: parent
            visible: input.text === ""
            text: root.placeholder
            color: Theme.textMuted
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.IBeamCursor
        onPressed: root.activated()
    }
}
