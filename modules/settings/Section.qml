import QtQuick
import QtQuick.Layouts
import qs.modules.settings
import qs.components
import qs.config
import qs.theme

// Titled block of settings. `paths` are the config paths it edits: a dot marks the
// title when any of them is overridden, and Reset removes those overrides.
ColumnLayout {
    id: root

    property string title
    property var paths: []
    default property alias content: body.data

    readonly property bool changed: {
        Config.overrides; // re-evaluate when overrides change
        return paths.some(p => Config.isOverridden(p));
    }

    spacing: Theme.panelGap

    RowLayout {
        Layout.fillWidth: true
        spacing: Theme.panelGap

        StyledText {
            text: root.title
            font.bold: true
        }
        Rectangle {
            visible: root.changed
            implicitWidth: Theme.panelGap
            implicitHeight: Theme.panelGap
            radius: width / 2
            color: Theme.accent
        }
        Item {
            Layout.fillWidth: true
        }
        Chip {
            visible: root.changed
            text: "Reset"
            onClicked: root.paths.forEach(p => Config.reset(p))
        }
    }

    ColumnLayout {
        id: body
        Layout.fillWidth: true
        spacing: Theme.panelGap
    }
}
