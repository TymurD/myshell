pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.UPower

// Battery state (UPower) + power profiles. Profiles go through the
// net.hadess.PowerProfiles D-Bus API, which tlp-pd provides here: no root needed.
Singleton {
    id: root

    readonly property var dev: UPower.displayDevice
    readonly property bool present: dev?.isLaptopBattery ?? false
    readonly property int percent: Math.round((dev?.percentage ?? 0) * 100)
    readonly property int state: dev?.state ?? UPowerDeviceState.Unknown
    readonly property bool charging: state === UPowerDeviceState.Charging
    readonly property bool full: state === UPowerDeviceState.FullyCharged
    readonly property bool onBattery: UPower.onBattery
    readonly property bool low: percent <= 15 && !charging

    readonly property real watts: Math.abs(dev?.changeRate ?? 0)
    readonly property real energy: dev?.energy ?? 0             // Wh
    readonly property real capacity: dev?.energyCapacity ?? 0   // Wh
    readonly property bool healthSupported: dev?.healthSupported ?? false
    readonly property real health: dev?.healthPercentage ?? 0
    readonly property real secondsLeft: charging ? (dev?.timeToFull ?? 0) : (dev?.timeToEmpty ?? 0)

    readonly property string stateText: full ? "Fully charged" : charging ? "Charging" : onBattery ? "Discharging" : "Plugged in"

    // Power profiles
    readonly property int profile: PowerProfiles.profile
    readonly property bool hasPerformance: PowerProfiles.hasPerformanceProfile
    readonly property string degradation: PowerProfiles.degradationReason === PerformanceDegradationReason.None ? "" : PerformanceDegradationReason.toString(PowerProfiles.degradationReason)

    readonly property var profiles: [
        {
            id: PowerProfile.PowerSaver,
            name: "Saver",
            icon: 0xF032A
        },
        {
            id: PowerProfile.Balanced,
            name: "Balanced",
            icon: 0xF05D1
        },
        {
            id: PowerProfile.Performance,
            name: "Performance",
            icon: 0xF04C5
        }
    ]

    function setProfile(p: int): void {
        PowerProfiles.profile = p;
    }

    function icon(): int {
        if (charging)
            return 0xF0084;
        // nf-md-battery-10 .. battery (full), in 10% steps
        const steps = [0xF007A, 0xF007B, 0xF007C, 0xF007D, 0xF007E, 0xF007F, 0xF0080, 0xF0081, 0xF0082, 0xF0079];
        return steps[Math.min(9, Math.max(0, Math.ceil(percent / 10) - 1))];
    }

    function formatDuration(s: real): string {
        if (!s || s <= 0)
            return "";
        const h = Math.floor(s / 3600);
        const m = Math.round((s % 3600) / 60);
        return h > 0 ? `${h}h ${m}m` : `${m}m`;
    }
}
