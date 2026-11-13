import QtQuick
import qs.config
import qs.core
import qs.theme

// One panel position in OverlayWindow: a main panel (+ optional attached panel) with
// its own open progress `t` and a snapshot of how it was opened. OverlayWindow keeps
// two of these so a swap can roll one up while the other unrolls.
FocusScope {
    id: s

    property bool isActive: false
    property bool shown: false   // the overlay has a panel open on this screen

    function lerp(a: real, b: real, k: real): real {
        return a + (b - a) * k;
    }

    // Loaded panel plus a snapshot of how it was opened. Set only by load().
    property string loadedId: ""
    property string attachedId: ""
    property string attachedSide: "left"
    property string source: ""
    property string pillSide: ""
    property var anchor: null

    readonly property var placement: Registry.placement(loadedId)
    // From the bar: the pill decides (bar.panelAt), unless the panel overrides fromBar.
    readonly property string mode: source === "bar" ? (placement.fromBar ?? Config.bar.panelAt?.[pillSide] ?? "pill") : placement.fromIpc
    readonly property bool fromPill: source === "bar" && anchor !== null

    // open progress 0..1, animated towards tTarget
    property real tTarget: 0
    property real t: tTarget
    readonly property bool settled: t >= 1

    readonly property Item panel: panelScope
    readonly property Item side: sideScope

    function load(id: string): void {
        source = PanelManager.source;
        pillSide = PanelManager.pillSide;
        anchor = PanelManager.anchor;
        loadedId = id;
        // Derived from `id`, not PanelManager.attachedId: that binding may not have
        // re-evaluated yet when openId's change reaches us.
        attachedId = PanelManager.attachedFor(id);
        if (attachedId)
            attachedSide = Registry.placement(attachedId).attach?.side ?? "left";
    }

    function panelX(w: real): real {
        const m = Theme.barMargin;
        switch (mode) {
        case "edge-left":
            return m;
        case "edge-right":
            return width - w - m;
        case "pill":
            if (anchor)
                return Math.max(m, Math.min(width - w - m, anchor.x + anchor.width / 2 - w / 2));
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

    anchors.fill: parent
    z: isActive ? 1 : 0
    focus: isActive

    Behavior on t {
        NumberAnimation {
            duration: s.fromPill && s.tTarget > 0 ? Anim.slow : Anim.normal
            easing.type: s.tTarget > 0 ? Anim.standard : Anim.exit
        }
    }

    // The slot that lost a swap unloads once it has rolled up.
    onTChanged: if (t <= 0 && !isActive) {
        loadedId = "";
        attachedId = "";
    }

    // Target rect of the main panel.
    QtObject {
        id: target

        property real w: loader.item?.implicitWidth ?? 0
        // placement.fillHeight: stretch down to the bottom gap (same as the outer gap above)
        property real h: s.placement.fillHeight ? s.height - (Theme.barMargin + Theme.barHeight + Theme.panelGap) - Theme.barMargin : loader.item?.implicitHeight ?? 0
        property real x: s.panelX(w)
        property real y: s.panelY(h)
    }

    // Where the main panel comes from / goes back to. It never travels: from the bar it
    // unrolls downward in place (a bar-high strip growing to full height, content
    // revealed by the clip); from a keybind it fades in with a small slide.
    QtObject {
        id: origin

        readonly property real x: target.x
        readonly property real y: s.fromPill ? target.y : target.y - Theme.panelGap * 1.5
        readonly property real w: target.w
        readonly property real h: s.fromPill ? Math.min(Theme.barHeight, target.h) : target.h
    }

    // Pill-coloured capsule that grows from the pill into the panel (bar-opened only).
    Rectangle {
        x: panelScope.x
        y: panelScope.y
        width: panelScope.width
        height: panelScope.height
        visible: s.fromPill && s.t > 0 && !s.settled
        opacity: Math.min(1, s.t * 4)
        radius: s.lerp(origin.h / 2, Theme.radius, s.t)
        color: Qt.rgba(s.lerp(Theme.bg.r, Theme.bgPanel.r, s.t), s.lerp(Theme.bg.g, Theme.bgPanel.g, s.t), s.lerp(Theme.bg.b, Theme.bgPanel.b, s.t), s.lerp(Theme.bg.a, Theme.bgPanel.a, s.t))
        border.color: Theme.border
        border.width: Theme.borderWidth
    }

    FocusScope {
        id: panelScope

        x: s.lerp(origin.x, target.x, s.t)
        y: s.lerp(origin.y, target.y, s.t)
        width: s.lerp(origin.w, target.w, s.t)
        height: s.lerp(origin.h, target.h, s.t)
        visible: s.t > 0 && s.loadedId !== ""
        focus: s.shown && PanelManager.focusId !== s.attachedId
        clip: true

        Keys.onEscapePressed: PanelManager.close()

        Loader {
            id: loader

            // Content keeps its final size while the slot grows around it, so it does
            // not reflow during the pill animation. When settled it follows the slot.
            width: target.w
            height: target.h
            x: (panelScope.width - width) / 2
            focus: true
            active: s.loadedId !== ""
            source: Registry.panelUrl(s.loadedId)
            opacity: s.fromPill ? Math.max(0, Math.min(1, (s.t - 0.15) / 0.5)) : s.t
            onLoaded: {
                if (item.panelId !== undefined)
                    item.panelId = s.loadedId;
            }
        }
    }

    // Attached panel (e.g. clipboard beside the launcher): same height as the main
    // panel, slides out from behind it.
    FocusScope {
        id: sideScope

        readonly property real w: sideLoader.item?.implicitWidth ?? 0
        readonly property real slide: (1 - s.t) * Theme.panelGap * 3

        width: w
        height: target.h
        x: s.attachedSide === "left" ? target.x - Theme.panelGap - w + slide : target.x + target.w + Theme.panelGap - slide
        y: target.y
        opacity: s.t
        visible: s.t > 0 && s.attachedId !== ""
        focus: s.shown && PanelManager.focusId === s.attachedId

        Keys.onEscapePressed: PanelManager.close()

        Loader {
            id: sideLoader

            anchors.fill: parent
            focus: true
            active: s.attachedId !== ""
            source: s.attachedId ? Registry.panelUrl(s.attachedId) : ""
            onLoaded: {
                if (item.panelId !== undefined)
                    item.panelId = s.attachedId;
            }
        }
    }
}
