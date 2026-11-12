import QtQuick
import qs.modules.sysstats
import qs.theme

// Thin horizontal bar, value 0..1. Turns urgent above `warnAt`.
Rectangle {
    id: root

    property real value: 0
    property real warnAt: 0.9

    implicitHeight: 4
    radius: height / 2
    color: Theme.textFaint

    Rectangle {
        width: parent.width * Math.max(0, Math.min(1, root.value))
        height: parent.height
        radius: parent.radius
        color: root.value >= root.warnAt ? Theme.urgent : Theme.accent

        Behavior on width {
            NumberAnimation {
                duration: Anim.normal
                easing.type: Anim.standard
            }
        }
    }
}
