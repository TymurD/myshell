import QtQuick
import qs.components
import qs.services
import qs.theme

// Click → timers panel (see Registry). Shows, in order of priority: the soonest
// running timer, the running stopwatch, the next enabled alarm, or "Timer".
BarButton {
    readonly property bool stopwatchShown: Timers.stopwatch.running
    readonly property var alarm: Timers.nextAlarm

    Row {
        spacing: 6
        Icon {
            code: Timers.nextTimer ? 0xF051B : stopwatchShown ? 0xF13AB : alarm ? 0xF0020 : 0xF051B
            color: Timers.nextTimer || stopwatchShown ? Theme.text : Theme.textDim
        }
        StyledText {
            text: Timers.nextTimer ? Timers.nextTimerText
                : stopwatchShown ? Timers.formatStopwatch(Timers.stopwatchElapsed).replace(/\.\d$/, "")
                : alarm ? Timers.formatClock(alarm.hour, alarm.minute)
                : "Timer"
            color: Timers.nextTimer || stopwatchShown ? Theme.text : Theme.textDim
        }
    }
}
