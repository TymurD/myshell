import QtQuick
import QtQuick.Layouts
import qs.modules.sysstats
import qs.components
import qs.services
import qs.theme

// Common layout for the stat cards: header (icon, title, value), subtitle,
// sparkline, then any extra children. Keeps SysStats polling while visible.
Item {
    id: root

    property int icon: 0
    property string title
    property string value
    property string subtitle
    property var history: []
    property real historyMax: 100
    property bool showGraph: true
    default property alias extra: extraCol.data

    implicitHeight: col.implicitHeight

    // Poll only while shown: the panel stays loaded (but invisible) after closing.
    property bool _held: false
    function syncHold(): void {
        if (visible && !_held) {
            SysStats.retain();
            _held = true;
        } else if (!visible && _held) {
            SysStats.release();
            _held = false;
        }
    }
    onVisibleChanged: syncHold()
    Component.onCompleted: syncHold()
    Component.onDestruction: {
        if (_held)
            SysStats.release();
    }

    ColumnLayout {
        id: col
        width: parent.width
        spacing: 6

        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            Icon {
                code: root.icon
                color: Theme.text
            }
            StyledText {
                text: root.title
                Layout.fillWidth: true
                elide: Text.ElideRight
            }
            StyledText {
                text: root.value
            }
        }
        StyledText {
            visible: text !== ""
            text: root.subtitle
            color: Theme.textDim
            font.pixelSize: Theme.fontSizeSmall
            Layout.fillWidth: true
            elide: Text.ElideRight
        }
        Sparkline {
            visible: root.showGraph
            Layout.fillWidth: true
            values: root.history
            max: root.historyMax
            capacity: SysStats.historyLength
        }
        ColumnLayout {
            id: extraCol
            Layout.fillWidth: true
            spacing: 4
        }
    }
}
