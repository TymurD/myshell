import QtQuick
import QtQuick.Layouts
import qs.modules.sysstats
import qs.components
import qs.services
import qs.theme

// RAM usage + history, swap bar.
StatCard {
    icon: 0xF035B
    title: "Memory"
    value: Math.round(SysStats.memPercent) + "%"
    subtitle: SysStats.formatKb(SysStats.memUsed) + " / " + SysStats.formatKb(SysStats.memTotal)
    history: SysStats.memHistory

    RowLayout {
        Layout.fillWidth: true
        visible: SysStats.swapTotal > 0
        spacing: 8
        StyledText {
            text: "Swap"
            color: Theme.textDim
            font.pixelSize: Theme.fontSizeSmall
        }
        Meter {
            Layout.fillWidth: true
            value: SysStats.swapPercent / 100
        }
        StyledText {
            text: SysStats.formatKb(SysStats.swapUsed)
            color: Theme.textDim
            font.pixelSize: Theme.fontSizeSmall
        }
    }
}
