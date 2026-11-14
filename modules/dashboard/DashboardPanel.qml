import QtQuick
import QtQuick.Layouts
import qs.modules.dashboard
import qs.components
import qs.config
import qs.core
import qs.services
import qs.theme

// Main dashboard (opened from the clock): card column | big date + calendar | card column.
// Side columns come from settings.json → dashboard.left / dashboard.right (card ids).
PanelSurface {
    id: root

    property string panelId

    readonly property var leftIds: Config.dashboard?.left ?? []
    readonly property var rightIds: Config.dashboard?.right ?? []
    readonly property real sideWidth: Config.dashboard?.sideWidth ?? 320

    implicitWidth: row.implicitWidth + 2 * Theme.panelPadding
    implicitHeight: row.implicitHeight + 2 * Theme.panelPadding

    RowLayout {
        id: row
        anchors.fill: parent
        anchors.margins: Theme.panelPadding
        spacing: Theme.panelPadding

        CardColumn {
            visible: root.leftIds.length > 0
            ids: root.leftIds
            Layout.preferredWidth: root.sideWidth
            Layout.fillHeight: true
        }

        ColumnLayout {
            Layout.alignment: Qt.AlignTop
            spacing: 2

            RowLayout {
                Layout.fillWidth: true

                StyledText {
                    text: Time.format("dddd")
                    color: Theme.textDim
                }
                Item {
                    Layout.fillWidth: true
                }
                SettingsButton {
                    onClicked: PanelManager.swap("settings")
                }
            }
            StyledText {
                text: Time.format("d MMMM")
                font.pixelSize: Theme.fontSizeXL
                font.bold: true
            }
            StyledText {
                Layout.bottomMargin: Theme.panelPadding * 0.5
                text: Time.format(Config.clock?.format ?? "HH:mm") + (Timers.nextTimer ? "  ·  " + Timers.nextTimer.name + " " + Timers.nextTimerText : "")
                color: Theme.textDim
                font.pixelSize: Theme.fontSizeSmall
            }
            MonthCalendar {
                Layout.preferredWidth: implicitWidth
            }
        }

        CardColumn {
            visible: root.rightIds.length > 0
            ids: root.rightIds
            Layout.preferredWidth: root.sideWidth
            Layout.fillHeight: true
        }
    }
}
