import QtQuick
import QtQuick.Layouts
import qs.modules.timers
import qs.components
import qs.services
import qs.theme

// Dashboard card: quick presets, running timers, stopwatch (if used), next alarm.
// Full controls live in the "timers" panel.
Item {
    id: root

    implicitHeight: col.implicitHeight

    TimersHold {
        active: root.visible
    }

    ColumnLayout {
        id: col
        width: parent.width
        spacing: 8

        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            Icon {
                code: 0xF051B
                color: Theme.text
            }
            StyledText {
                text: "Timers"
                Layout.fillWidth: true
            }
            StyledText {
                visible: Timers.nextAlarm !== null
                text: Timers.nextAlarm ? "Alarm " + Timers.formatClock(Timers.nextAlarm.hour, Timers.nextAlarm.minute) : ""
                color: Theme.textDim
                font.pixelSize: Theme.fontSizeSmall
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 6
            Repeater {
                model: Timers.presets
                Chip {
                    required property int modelData
                    Layout.fillWidth: true
                    text: Timers.presetLabel(modelData)
                    onClicked: Timers.start(modelData, "")
                }
            }
        }

        Repeater {
            model: Timers.timers
            TimerRow {
                required property var modelData
                Layout.fillWidth: true
                timer: modelData
                compact: true
            }
        }

        RowLayout {
            visible: Timers.stopwatch.running || Timers.stopwatchElapsed > 0
            Layout.fillWidth: true
            spacing: 8
            Icon {
                code: 0xF13AB
                color: Theme.text
            }
            StyledText {
                Layout.fillWidth: true
                text: "Stopwatch"
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.textDim
            }
            StyledText {
                text: Timers.formatStopwatch(Timers.stopwatchElapsed)
            }
            IconButton {
                icon: Timers.stopwatch.running ? 0xF03E4 : 0xF040A
                onClicked: Timers.toggleStopwatch()
            }
            IconButton {
                icon: 0xF0459
                onClicked: Timers.resetStopwatch()
            }
        }
    }
}
