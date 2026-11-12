import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.config
import qs.core
import qs.theme
// Panels are loaded by URL, and Quickshell only scans a module folder (so its
// sibling types and `import qs.modules.<id>` resolve) when some statically loaded
// file imports it. Import every panel folder here. Add new panel folders too.
import qs.modules.battery
import qs.modules.clipboard
import qs.modules.dashboard
import qs.modules.launcher
import qs.modules.media
import qs.modules.network
import qs.modules.session
import qs.modules.sysstats
import qs.modules.timers
import qs.modules.weather

// Fullscreen transparent layer per screen that hosts expanded panels.
// Input is masked to the visible panel(s), so the rest of the screen stays clickable.
//
// Animation model: `t` runs 0 → 1 on open and 1 → 0 on close. The slot's rect is
// lerp(origin, target, t).
//  - From the bar, the panel unrolls downward in place: a bar-high strip (pill
//    coloured "shell") grows to full height and the clip reveals the content; on
//    close it rolls back up. It never travels from the pill's position.
//  - From a keybind, origin = target nudged up: fade + slide.
//  - Switching panels while open (t = 1) animates the target rect: in-place morph
//    with a content cross-fade.
// An attached panel (placement.attach) gets its own slot beside the main one.
PanelWindow {
    id: root

    property var barWindow

    readonly property bool shown: PanelManager.isOpen && PanelManager.screenName === (screen?.name ?? "")
    property string loadedId: ""
    property string attachedId: ""
    property string attachedSide: "left"
    readonly property var placement: Registry.placement(loadedId)
    // From the bar: the pill decides (bar.panelAt), unless the panel overrides fromBar.
    readonly property string mode: PanelManager.source === "bar" ? (placement.fromBar ?? Config.bar.panelAt?.[PanelManager.pillSide] ?? "pill") : placement.fromIpc
    readonly property bool fromPill: PanelManager.source === "bar" && PanelManager.anchor !== null

    // open progress 0..1
    property real t: shown ? 1 : 0
    readonly property bool settled: t >= 1

    Behavior on t {
        NumberAnimation {
            duration: root.fromPill && root.shown ? Anim.slow : Anim.normal
            easing.type: root.shown ? Anim.standard : Anim.exit
        }
    }

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
    // Exclusive for every panel, and constant while open: changing the keyboard mode
    // while a panel is showing (e.g. battery → session in one pill) makes Hyprland
    // drop the focus grab, which closed everything. Click-outside closes anyway.
    WlrLayershell.keyboardFocus: shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    mask: Region {
        item: slot.visible ? slot : null
        Region {
            item: side.visible ? side : null
        }
    }

    // Keep the last panel(s) loaded while they animate out.
    Binding {
        target: root
        property: "loadedId"
        value: PanelManager.openId
        when: root.shown
        restoreMode: Binding.RestoreNone
    }
    Binding {
        target: root
        property: "attachedId"
        value: PanelManager.attachedId
        when: root.shown
        restoreMode: Binding.RestoreNone
    }
    Binding {
        target: root
        property: "attachedSide"
        value: PanelManager.attachedSide
        when: root.shown && PanelManager.attachedId !== ""
        restoreMode: Binding.RestoreNone
    }

    HyprlandFocusGrab {
        // Activated once the panel has an input region: a grab on a surface with an
        // empty mask is cleared by Hyprland right away.
        active: root.shown && root.settled
        windows: [root, root.barWindow]
        onCleared: PanelManager.close()
    }

    function lerp(a: real, b: real, k: real): real {
        return a + (b - a) * k;
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

    // Target rect of the main panel. Animated while settled, so a swap morphs in place.
    QtObject {
        id: target

        property real w: loader.item?.implicitWidth ?? 0
        property real h: loader.item?.implicitHeight ?? 0
        property real x: root.panelX(w)
        property real y: root.panelY(h)

        Behavior on w {
            enabled: root.settled
            NumberAnimation {
                duration: Anim.normal
                easing.type: Anim.standard
            }
        }
        Behavior on h {
            enabled: root.settled
            NumberAnimation {
                duration: Anim.normal
                easing.type: Anim.standard
            }
        }
        Behavior on x {
            enabled: root.settled
            NumberAnimation {
                duration: Anim.normal
                easing.type: Anim.standard
            }
        }
        Behavior on y {
            enabled: root.settled
            NumberAnimation {
                duration: Anim.normal
                easing.type: Anim.standard
            }
        }
    }

    // Where the main panel comes from / goes back to. It never travels: from the bar it
    // unrolls downward in place (a bar-high strip growing to full height, content
    // revealed by the clip); from a keybind it fades in with a small slide.
    QtObject {
        id: origin

        readonly property real x: target.x
        readonly property real y: root.fromPill ? target.y : target.y - Theme.panelGap * 1.5
        readonly property real w: target.w
        readonly property real h: root.fromPill ? Math.min(Theme.barHeight, target.h) : target.h
    }

    // Pill-coloured capsule that grows from the pill into the panel (bar-opened only).
    Rectangle {
        id: shell

        x: slot.x
        y: slot.y
        width: slot.width
        height: slot.height
        visible: root.fromPill && root.t > 0 && !root.settled
        opacity: Math.min(1, root.t * 4)
        radius: root.lerp(origin.h / 2, Theme.radius, root.t)
        color: Qt.rgba(root.lerp(Theme.bg.r, Theme.bgSolid.r, root.t), root.lerp(Theme.bg.g, Theme.bgSolid.g, root.t), root.lerp(Theme.bg.b, Theme.bgSolid.b, root.t), root.lerp(Theme.bg.a, Theme.bgSolid.a, root.t))
        border.color: Theme.border
        border.width: Theme.borderWidth
    }

    FocusScope {
        id: slot

        x: root.lerp(origin.x, target.x, root.t)
        y: root.lerp(origin.y, target.y, root.t)
        width: root.lerp(origin.w, target.w, root.t)
        height: root.lerp(origin.h, target.h, root.t)
        visible: root.t > 0 && root.loadedId !== ""
        focus: root.shown && PanelManager.focusId !== root.attachedId
        clip: true

        Keys.onEscapePressed: PanelManager.close()

        Loader {
            id: loader

            // Content keeps its final size while the slot grows around it, so it does
            // not reflow during the pill animation. When settled it follows the slot.
            width: target.w
            height: target.h
            x: (slot.width - width) / 2
            focus: true
            active: root.loadedId !== ""
            source: Registry.panelUrl(root.loadedId)
            opacity: root.fromPill ? Math.max(0, Math.min(1, (root.t - 0.15) / 0.5)) : root.t
            onLoaded: {
                if (item.panelId !== undefined)
                    item.panelId = root.loadedId;
                if (root.settled) {
                    swapFade.target = item;
                    swapFade.restart();
                }
            }

            NumberAnimation {
                id: swapFade
                property: "opacity"
                from: 0
                to: 1
                duration: Anim.fast
            }
        }
    }

    // Attached panel (e.g. clipboard beside the launcher): same height as the main
    // panel, slides out from behind it.
    FocusScope {
        id: side

        readonly property real w: sideLoader.item?.implicitWidth ?? 0
        readonly property real slide: (1 - root.t) * Theme.panelGap * 3

        width: w
        height: target.h
        x: root.attachedSide === "left" ? target.x - Theme.panelGap - w + side.slide : target.x + target.w + Theme.panelGap - side.slide
        y: target.y
        opacity: root.t
        visible: root.t > 0 && root.attachedId !== ""
        focus: root.shown && PanelManager.focusId === root.attachedId

        Keys.onEscapePressed: PanelManager.close()

        Loader {
            id: sideLoader

            anchors.fill: parent
            focus: true
            active: root.attachedId !== ""
            source: root.attachedId ? Registry.panelUrl(root.attachedId) : ""
            onLoaded: {
                if (item.panelId !== undefined)
                    item.panelId = root.attachedId;
            }
        }
    }
}
