import QtQuick
import QtQuick.Layouts
import qs.modules.sysstats
import qs.components
import qs.services
import qs.theme

// Temperatures resolved by hwmon name (CPU package, board, NVMe, Wi-Fi) + dGPU when awake.
StatCard {
    id: root

    readonly property var rows: SysStats.temps.concat(SysStats.dgpuAwake && SysStats.dgpuHasData ? [
        {
            id: "gpu",
            title: "GPU",
            value: SysStats.dgpuTemp
        }
    ] : [])

    icon: 0xF050F
    title: "Temperatures"
    value: SysStats.formatTemp(SysStats.cpuTemp)
    history: SysStats.cpuTempHistory
    showGraph: SysStats.cpuTempHistory.length > 0

    Repeater {
        model: root.rows

        RowLayout {
            required property var modelData
            Layout.fillWidth: true
            spacing: 8
            StyledText {
                text: modelData.title
                color: Theme.textDim
                font.pixelSize: Theme.fontSizeSmall
                Layout.preferredWidth: 52
            }
            Meter {
                Layout.fillWidth: true
                value: (modelData.value ?? 0) / 100
                warnAt: 0.85
            }
            StyledText {
                text: SysStats.formatTemp(modelData.value)
                font.pixelSize: Theme.fontSizeSmall
                horizontalAlignment: Text.AlignRight
                Layout.preferredWidth: 44
            }
        }
    }
}
