pragma Singleton

import QtQuick
import Quickshell

// Animation tokens. Use these instead of literal durations/easings.
Singleton {
    readonly property int fast: 150
    readonly property int normal: 250
    readonly property int slow: 400

    readonly property int standard: Easing.OutCubic
    readonly property int emphasized: Easing.OutBack
    readonly property int exit: Easing.InCubic
}
