import QtQuick
import qs.components
import qs.services
import qs.theme

// Sun icon + percent. Scroll to adjust, click opens the brightness panel.
BarButton {
    shown: Brightness.available

    onWheel: wheel => {
        if (wheel.angleDelta.y > 0)
            Brightness.up();
        else if (wheel.angleDelta.y < 0)
            Brightness.down();
    }

    Row {
        spacing: 6
        Icon {
            code: Brightness.icon()
            color: Theme.textDim
        }
        StyledText {
            text: Brightness.percent + "%"
        }
    }
}
