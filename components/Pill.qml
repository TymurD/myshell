import QtQuick
import qs.core
import qs.theme

// One continuous capsule holding a list of bar modules side by side (no separators).
// Panels opened from any module in this pill anchor to the pill itself.
Rectangle {
    id: root

    property string side         // "left" | "center" | "right"
    property var modules: []
    property var barScreen

    visible: modules.length > 0
    implicitWidth: row.implicitWidth + 2 * Theme.borderWidth
    implicitHeight: Theme.barHeight
    radius: height / 2
    color: Theme.bg
    border.color: Theme.border
    border.width: Theme.borderWidth

    Behavior on implicitWidth {
        NumberAnimation {
            duration: Anim.normal
            easing.type: Anim.standard
        }
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 0

        Repeater {
            model: root.modules

            Loader {
                required property string modelData
                anchors.verticalCenter: parent.verticalCenter
                visible: item?.shown ?? false
                Component.onCompleted: setSource(Registry.barUrl(modelData), {
                    moduleId: modelData,
                    barScreen: root.barScreen,
                    pill: root
                })
            }
        }
    }
}
