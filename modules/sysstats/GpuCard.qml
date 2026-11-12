import QtQuick
import QtQuick.Layouts
import qs.modules.sysstats
import qs.components
import qs.services
import qs.theme

// Discrete NVIDIA GPU (only queried while it is awake) + Intel iGPU frequency.
StatCard {
    icon: 0xF08AE
    title: SysStats.dgpuPresent ? SysStats.dgpuName : "GPU"
    value: !SysStats.dgpuPresent ? "" : !SysStats.dgpuAwake ? "sleeping" : SysStats.dgpuHasData ? Math.round(SysStats.dgpuUtil) + "%" : "…"
    subtitle: SysStats.dgpuAwake && SysStats.dgpuHasData ? [Math.round(SysStats.dgpuMemUsed) + " / " + Math.round(SysStats.dgpuMemTotal) + " MiB", SysStats.formatTemp(SysStats.dgpuTemp), isNaN(SysStats.dgpuPower) ? "" : SysStats.dgpuPower.toFixed(1) + " W"].filter(s => s !== "").join(" · ") : SysStats.dgpuPresent ? "Runtime-suspended, not polled" : ""
    history: SysStats.dgpuHistory
    showGraph: SysStats.dgpuPresent

    RowLayout {
        Layout.fillWidth: true
        visible: SysStats.igpuPath !== ""
        spacing: 8
        StyledText {
            text: "iGPU"
            color: Theme.textDim
            font.pixelSize: Theme.fontSizeSmall
        }
        Meter {
            Layout.fillWidth: true
            value: SysStats.igpuPercent / 100
            warnAt: 2
        }
        StyledText {
            text: Math.round(SysStats.igpuFreq) + " MHz"
            color: Theme.textDim
            font.pixelSize: Theme.fontSizeSmall
        }
    }
}
