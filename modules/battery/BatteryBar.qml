import QtQuick
import qs.components
import qs.services
import qs.theme

BarButton {
    shown: Battery.present

    Row {
        spacing: 6
        Icon {
            code: Battery.icon()
            color: Battery.low ? Theme.urgent : Theme.textDim
        }
        StyledText {
            text: Battery.percent + "%"
            color: Battery.low ? Theme.urgent : Theme.text
        }
    }
}
