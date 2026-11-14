import QtQuick
import qs.modules.settings
import qs.components
import qs.theme

// One entry in a ListEditor column: name on the left, small buttons on the right.
Rectangle {
    id: root

    property string name
    property bool dim: false
    default property alias buttons: btns.data

    implicitHeight: btns.implicitHeight + Theme.panelGap / 2
    radius: Theme.radiusSmall
    color: Theme.surface
    border.color: Theme.border
    border.width: Theme.borderWidth

    StyledText {
        anchors.left: parent.left
        anchors.leftMargin: Theme.panelGap
        anchors.right: btns.left
        anchors.verticalCenter: parent.verticalCenter
        text: root.name
        elide: Text.ElideRight
        color: root.dim ? Theme.textMuted : Theme.text
        font.pixelSize: Theme.fontSizeSmall
    }

    Row {
        id: btns
        anchors.right: parent.right
        anchors.rightMargin: Theme.panelGap / 4
        anchors.verticalCenter: parent.verticalCenter
        spacing: 0
    }
}
