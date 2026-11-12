import QtQuick
import QtQuick.Layouts
import qs.modules.timers
import qs.components
import qs.services
import qs.theme

// One alarm: time, name, once/daily, enable, delete.
RowLayout {
    id: root

    required property var alarm
    property bool compact: false

    spacing: 8
    opacity: alarm.enabled ? 1 : 0.5

    Icon {
        code: root.alarm.enabled ? 0xF0020 : 0xF0023
        color: Theme.text
    }
    StyledText {
        text: Timers.formatClock(root.alarm.hour, root.alarm.minute)
        font.pixelSize: root.compact ? Theme.fontSize : Theme.fontSizeLarge
    }
    StyledText {
        Layout.fillWidth: true
        text: root.alarm.name !== "" ? root.alarm.name : root.alarm.daily ? "Every day" : "Once"
        elide: Text.ElideRight
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.textDim
    }
    Chip {
        visible: !root.compact
        text: root.alarm.daily ? "Daily" : "Once"
        onClicked: Timers.setAlarmDaily(root.alarm.id, !root.alarm.daily)
    }
    Chip {
        text: root.alarm.enabled ? "On" : "Off"
        checked: root.alarm.enabled
        onClicked: Timers.setAlarmEnabled(root.alarm.id, !root.alarm.enabled)
    }
    IconButton {
        visible: !root.compact
        icon: 0xF01B4
        onClicked: Timers.removeAlarm(root.alarm.id)
    }
}
