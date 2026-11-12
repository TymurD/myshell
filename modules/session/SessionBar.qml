import QtQuick
import qs.components
import qs.core
import qs.services
import qs.theme

// Power icon (pure action, so a lone icon is fine). Click → session panel.
BarButton {
    id: root

    readonly property bool active: PanelManager.openId === "session"

    Icon {
        code: 0xF0425 // nf-md-power
        color: root.active || root.containsMouse ? Theme.text : Theme.textDim
        Behavior on color {
            ColorAnimation {
                duration: Anim.fast
            }
        }
    }
}
