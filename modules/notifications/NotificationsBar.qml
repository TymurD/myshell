import QtQuick
import qs.components
import qs.services
import qs.theme

// Bell + unread count. Bell-off while Do Not Disturb is on. Right click toggles DND.
BarButton {
    id: root

    onRightClicked: Notifications.toggleDnd()

    Row {
        spacing: 6

        Icon {
            anchors.verticalCenter: parent.verticalCenter
            // nf-md-bell_off_outline / bell_badge / bell_outline
            code: Notifications.dnd ? 0xF009B : Notifications.unread > 0 ? 0xF116B : 0xF009C
            color: Notifications.unread > 0 && !Notifications.dnd ? Theme.text : Theme.textDim
        }
        StyledText {
            anchors.verticalCenter: parent.verticalCenter
            visible: Notifications.unread > 0
            text: Notifications.unread > 99 ? "99+" : Notifications.unread
        }
    }
}
