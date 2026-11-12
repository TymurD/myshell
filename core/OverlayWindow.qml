import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.config
import qs.core
import qs.theme

// Fullscreen transparent layer per screen that hosts expanded panels.
// Input is masked to the visible panel, so the rest of the screen stays clickable.
PanelWindow {
    id: root

    property var barWindow

    readonly property bool shown: PanelManager.isOpen && PanelManager.screenName === (screen?.name ?? "")
    property string loadedId: ""
    readonly property var placement: Registry.placement(loadedId)
    // From the bar: the pill decides (bar.panelAt), unless the panel overrides fromBar.
    readonly property string mode: PanelManager.source === "bar" ? (placement.fromBar ?? Config.bar.panelAt?.[PanelManager.pillSide] ?? "pill") : placement.fromIpc

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "myshell-overlay"
    WlrLayershell.keyboardFocus: shown ? (placement.keyboard ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.OnDemand) : WlrKeyboardFocus.None

    mask: Region {
        item: slot.visible ? slot : null
    }

    // Keep the last panel loaded while it animates out.
    Binding {
        target: root
        property: "loadedId"
        value: PanelManager.openId
        when: root.shown
        restoreMode: Binding.RestoreNone
    }

    HyprlandFocusGrab {
        active: root.shown
        windows: [root, root.barWindow]
        onCleared: PanelManager.close()
    }

    function panelX(w: real): real {
        const m = Theme.barMargin;
        switch (mode) {
        case "edge-left":
            return m;
        case "edge-right":
            return width - w - m;
        case "pill":
            if (PanelManager.anchor)
                return Math.max(m, Math.min(width - w - m, PanelManager.anchor.x + PanelManager.anchor.width / 2 - w / 2));
            return (width - w) / 2;
        default: // "center", "center-top"
            return (width - w) / 2;
        }
    }

    function panelY(h: real): real {
        if (mode === "center")
            return (height - h) / 2;
        return Theme.barMargin + Theme.barHeight + Theme.panelGap;
    }

    Item {
        id: slot

        readonly property real targetW: loader.item?.implicitWidth ?? 0
        readonly property real targetH: loader.item?.implicitHeight ?? 0

        // Size animates, so switching panels inside one pill morphs in place.
        width: targetW
        height: targetH
        x: root.panelX(targetW)
        y: root.panelY(targetH) + (root.shown ? 0 : -12)
        opacity: root.shown ? 1 : 0
        visible: opacity > 0
        focus: root.shown
        clip: true

        Behavior on width {
            enabled: root.shown
            NumberAnimation {
                duration: Anim.normal
                easing.type: Anim.standard
            }
        }
        Behavior on height {
            enabled: root.shown
            NumberAnimation {
                duration: Anim.normal
                easing.type: Anim.standard
            }
        }
        Behavior on x {
            enabled: root.shown
            NumberAnimation {
                duration: Anim.normal
                easing.type: Anim.standard
            }
        }
        Behavior on opacity {
            NumberAnimation {
                duration: Anim.normal
                easing.type: Anim.standard
            }
        }
        Behavior on y {
            NumberAnimation {
                duration: Anim.normal
                easing.type: Anim.standard
            }
        }

        Keys.onEscapePressed: PanelManager.close()

        Loader {
            id: loader
            width: slot.width
            height: slot.height
            active: root.loadedId !== ""
            source: Registry.panelUrl(root.loadedId)
            onLoaded: {
                if (item.panelId !== undefined)
                    item.panelId = root.loadedId;
                swapFade.restart();
            }
        }

        NumberAnimation {
            id: swapFade
            target: loader
            property: "opacity"
            from: 0
            to: 1
            duration: Anim.fast
        }
    }
}
