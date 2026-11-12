import QtQuick
import QtQuick.Layouts
import qs.modules.sysstats
import qs.services
import qs.theme

// CPU usage + history, frequency, package temperature and per-core bars.
StatCard {
    icon: 0xF0EE0
    title: "CPU"
    value: Math.round(SysStats.cpuUsage) + "%"
    subtitle: [SysStats.cpuFreqGHz > 0 ? SysStats.cpuFreqGHz.toFixed(1) + " GHz" : "", isNaN(SysStats.cpuTemp) ? "" : SysStats.formatTemp(SysStats.cpuTemp), SysStats.cpuCores.length > 0 ? SysStats.cpuCores.length + " threads" : ""].filter(s => s !== "").join(" · ")
    history: SysStats.cpuHistory

    // per-core usage, one thin column each
    Item {
        Layout.fillWidth: true
        Layout.preferredHeight: 18

        Row {
            id: cores
            anchors.fill: parent
            spacing: 2
            readonly property int n: Math.max(1, SysStats.cpuCores.length)
            readonly property real barW: (width - (n - 1) * spacing) / n

            Repeater {
                model: SysStats.cpuCores

                Rectangle {
                    required property real modelData
                    width: cores.barW
                    height: cores.height
                    radius: 1
                    color: Theme.textFaint

                    Rectangle {
                        anchors.bottom: parent.bottom
                        width: parent.width
                        height: parent.height * parent.modelData / 100
                        radius: 1
                        color: parent.modelData >= 90 ? Theme.urgent : Theme.accent
                    }
                }
            }
        }
    }
}
