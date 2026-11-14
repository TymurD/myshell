import QtQuick
import QtQuick.Layouts
import qs.modules.settings
import qs.components
import qs.config
import qs.theme

// Label on the left, control(s) on the right. A dot marks an overridden `path`.
RowLayout {
    id: root

    property string label
    property string path
    default property alias content: controls.data

    readonly property bool changed: {
        Config.overrides;
        return path !== "" && Config.isOverridden(path);
    }

    Layout.fillWidth: true
    spacing: Theme.panelGap

    StyledText {
        text: root.label
        color: Theme.textDim
        font.pixelSize: Theme.fontSizeSmall
    }
    Rectangle {
        visible: root.changed
        implicitWidth: Theme.panelGap * 0.75
        implicitHeight: Theme.panelGap * 0.75
        radius: width / 2
        color: Theme.accent
    }
    Item {
        Layout.fillWidth: true
    }
    Row {
        id: controls
        spacing: Theme.panelGap / 2
    }
}
