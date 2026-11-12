import QtQuick
import qs.modules.weather
import qs.services

// Ask Weather for fresh data whenever the owning card becomes visible.
QtObject {
    property bool active: false
    onActiveChanged: if (active)
        Weather.ensureFresh()
    Component.onCompleted: if (active)
        Weather.ensureFresh()
}
