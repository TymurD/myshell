import QtQuick
import qs.components
import qs.services

// Click → next layout. OSD on switch comes in a later phase.
BarButton {
    onLeftClicked: KbLayout.next()

    Row {
        spacing: 6
        Icon {
            code: 0xF030C
        }
        StyledText {
            text: KbLayout.short
        }
    }
}
