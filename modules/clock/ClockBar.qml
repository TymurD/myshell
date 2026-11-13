import QtQuick
import qs.components
import qs.config
import qs.services
import qs.core
import qs.theme

// Click → dashboard (see Registry). Right click → timers (also its own bar item).
BarButton {
    onRightClicked: PanelManager.toggle("timers", "bar", pill)

    Row {
        spacing: 6
        Icon {
            code: 0xF0150
        }
        StyledText {
            text: Time.format(Config.clock.format ?? "HH:mm")
        }
    }
}
