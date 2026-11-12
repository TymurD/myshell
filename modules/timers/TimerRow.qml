import QtQuick
import QtQuick.Layouts
import qs.modules.timers
import qs.components
import qs.services
import qs.theme

// One countdown: name, remaining time, progress, pause/resume/restart/cancel.
ColumnLayout {
    id: root

    required property var timer
    property bool compact: false

    readonly property real remaining: timer.state === "running" ? Math.max(0, timer.endAt - Timers.now) : timer.state === "paused" ? timer.remaining : 0
    readonly property real progress: timer.duration > 0 ? 1 - remaining / timer.duration : 1

    spacing: 4

    RowLayout {
        Layout.fillWidth: true
        spacing: 8

        Icon {
            code: root.timer.state === "done" ? 0xF1AD0 : root.timer.state === "paused" ? 0xF1ADE : 0xF051B
            color: root.timer.state === "done" ? Theme.urgent : Theme.text
        }
        StyledText {
            Layout.fillWidth: true
            text: root.timer.name
            elide: Text.ElideRight
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.textDim
        }
        StyledText {
            text: root.timer.state === "done" ? "Done" : Timers.formatDuration(root.remaining)
            font.pixelSize: root.compact ? Theme.fontSize : Theme.fontSizeLarge
            color: root.timer.state === "paused" ? Theme.textDim : Theme.text
        }
        IconButton {
            visible: root.timer.state !== "done"
            icon: root.timer.state === "running" ? 0xF03E4 : 0xF040A
            onClicked: root.timer.state === "running" ? Timers.pause(root.timer.id) : Timers.resume(root.timer.id)
        }
        IconButton {
            visible: root.timer.state === "done" || !root.compact
            icon: 0xF0459
            onClicked: Timers.restart(root.timer.id)
        }
        IconButton {
            icon: 0xF0156
            onClicked: Timers.cancel(root.timer.id)
        }
    }
    Rectangle {
        Layout.fillWidth: true
        implicitHeight: 3
        radius: height / 2
        color: Theme.textFaint
        Rectangle {
            width: parent.width * Math.max(0, Math.min(1, root.progress))
            height: parent.height
            radius: parent.radius
            color: root.timer.state === "done" ? Theme.urgent : Theme.accent
        }
    }
}
