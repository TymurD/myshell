import QtQuick
import QtQuick.Layouts
import qs.modules.timers
import qs.components
import qs.services
import qs.theme

// Countdown timers (presets + custom), stopwatch and time-of-day alarms.
PanelSurface {
    id: root

    property string panelId

    implicitWidth: 440
    implicitHeight: col.implicitHeight + 2 * Theme.panelPadding

    TimersHold {
        active: root.visible
    }

    component Section: RowLayout {
        property int icon
        property string title
        default property alias extra: tail.data
        Layout.fillWidth: true
        Layout.topMargin: 4
        spacing: 8
        Icon {
            code: parent.icon
            color: Theme.text
        }
        StyledText {
            text: parent.title
            Layout.fillWidth: true
        }
        RowLayout {
            id: tail
            spacing: 6
        }
    }

    component Divider: Rectangle {
        Layout.fillWidth: true
        implicitHeight: Theme.borderWidth
        color: Theme.border
    }

    component Hint: StyledText {
        Layout.fillWidth: true
        color: Theme.textMuted
        font.pixelSize: Theme.fontSizeSmall
        wrapMode: Text.WordWrap
    }

    ColumnLayout {
        id: col
        anchors.fill: parent
        anchors.margins: Theme.panelPadding
        spacing: 10

        // ---- timers ----
        Section {
            icon: 0xF051B
            title: "Timers"
            Chip {
                visible: Timers.timers.some(t => t.state === "done")
                text: "Clear done"
                onClicked: Timers.clearDone()
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
                    onClicked: Timers.start(modelData, nameBox.text)
                }
            }
        }

        RowLayout {
            id: customRow
            Layout.fillWidth: true
            spacing: 6

            function startCustom(): void {
                const s = Timers.parseDuration(durBox.text);
                if (s <= 0) {
                    durError.visible = durBox.text !== "";
                    return;
                }
                durError.visible = false;
                Timers.start(s, nameBox.text);
                durBox.clear();
                nameBox.clear();
            }

            TextBox {
                id: nameBox
                Layout.fillWidth: true
                placeholder: "Name (optional)"
                onAccepted: customRow.startCustom()
            }
            TextBox {
                id: durBox
                Layout.preferredWidth: 130
                placeholder: "5m · 1:30 · 1h"
                onAccepted: customRow.startCustom()
            }
            IconButton {
                icon: 0xF040A
                highlighted: true
                onClicked: customRow.startCustom()
            }
        }
        Hint {
            id: durError
            visible: false
            color: Theme.urgent
            text: "Use e.g. 90s, 5m, 1h30m, 1:30 (min:sec) or a plain number of minutes"
        }

        Repeater {
            model: Timers.timers
            TimerRow {
                required property var modelData
                Layout.fillWidth: true
                timer: modelData
            }
        }
        Hint {
            visible: Timers.timers.length === 0
            text: "No timers. Pick a preset or type a duration."
        }

        Divider {}

        // ---- stopwatch ----
        Section {
            icon: 0xF13AB
            title: "Stopwatch"
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            StyledText {
                Layout.fillWidth: true
                text: Timers.formatStopwatch(Timers.stopwatchElapsed)
                font.pixelSize: Theme.fontSizeXL
                color: Timers.stopwatch.running || Timers.stopwatchElapsed === 0 ? Theme.text : Theme.textDim
            }
            IconButton {
                icon: Timers.stopwatch.running ? 0xF03E4 : 0xF040A
                highlighted: !Timers.stopwatch.running
                onClicked: Timers.toggleStopwatch()
            }
            IconButton {
                icon: 0xF0459
                enabled: Timers.stopwatchElapsed > 0
                opacity: enabled ? 1 : 0.4
                onClicked: Timers.resetStopwatch()
            }
        }

        Divider {}

        // ---- alarms ----
        Section {
            icon: 0xF0020
            title: "Alarms"
        }
        Repeater {
            model: Timers.alarms
            AlarmRow {
                required property var modelData
                Layout.fillWidth: true
                alarm: modelData
            }
        }
        Hint {
            visible: Timers.alarms.length === 0
            text: "No alarms."
        }

        RowLayout {
            id: addAlarm
            Layout.fillWidth: true
            spacing: 6
            property bool daily: false

            function add(): void {
                const t = Timers.parseClock(timeBox.text);
                if (!t) {
                    timeError.visible = true;
                    return;
                }
                timeError.visible = false;
                Timers.addAlarm(t.hour, t.minute, daily, alarmName.text);
                timeBox.clear();
                alarmName.clear();
            }

            TextBox {
                id: timeBox
                Layout.preferredWidth: 80
                placeholder: "07:30"
                onAccepted: addAlarm.add()
            }
            TextBox {
                id: alarmName
                Layout.fillWidth: true
                placeholder: "Label (optional)"
                onAccepted: addAlarm.add()
            }
            Chip {
                text: addAlarm.daily ? "Daily" : "Once"
                checked: addAlarm.daily
                onClicked: addAlarm.daily = !addAlarm.daily
            }
            IconButton {
                icon: 0xF0415
                highlighted: true
                onClicked: addAlarm.add()
            }
        }
        Hint {
            id: timeError
            visible: false
            color: Theme.urgent
            text: "Time as HH:MM (24h)"
        }
    }
}
