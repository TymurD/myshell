import QtQuick
import qs.components
import qs.services
import qs.theme

// Icon + connection name (SSID / wired), optional ↓↑ rates (settings: network.showSpeed).
BarButton {
    Row {
        spacing: 6

        Icon {
            code: Network.icon()
        }
        StyledText {
            text: Network.name
            color: Network.connected ? Theme.text : Theme.textDim
            width: Math.min(implicitWidth, 160)
            elide: Text.ElideRight
        }

        Row {
            visible: Network.speedEnabled && Network.connected
            spacing: 6
            leftPadding: 4

            Icon {
                code: 0xF0045
            }
            StyledText {
                text: Network.formatRate(Network.rxRate)
            }
            Icon {
                code: 0xF005D
            }
            StyledText {
                text: Network.formatRate(Network.txRate)
            }
        }
    }
}
