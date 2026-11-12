import QtQuick
import qs.theme

// Stand-in for panels that are registered but not implemented yet.
PanelSurface {
    property string panelId

    implicitWidth: 360
    implicitHeight: 140

    Column {
        anchors.centerIn: parent
        spacing: 6

        StyledText {
            anchors.horizontalCenter: parent.horizontalCenter
            text: panelId
            font.pixelSize: Theme.fontSizeLarge
        }
        StyledText {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "not implemented yet"
            color: Theme.textDim
            font.pixelSize: Theme.fontSizeSmall
        }
    }
}
