import QtQuick
import qs.components
import qs.config
import qs.services

// Click → dashboard (see Registry).
BarButton {
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
