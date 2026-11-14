import QtQuick
import QtQuick.Layouts
import qs.core
import qs.modules.dashboard
import qs.theme

// Vertical stack of dashboard cards from a list of ids (settings.json → dashboard.left/right).
// Each card is a module-style <Name>Card.qml living with its feature; this column
// only frames them so every card looks the same. Unknown ids are skipped with a warning.
ColumnLayout {
    id: root

    property var ids: []

    readonly property var cards: Registry.cards

    readonly property var known: {
        const out = [];
        for (const id of ids ?? []) {
            if (cards[id])
                out.push(id);
            else
                console.warn("Dashboard: unknown card id", JSON.stringify(id), "- known:", Object.keys(cards).join(", "));
        }
        return out;
    }

    spacing: Theme.panelGap

    Repeater {
        model: root.known

        Rectangle {
            id: frame
            required property string modelData

            Layout.fillWidth: true
            implicitHeight: loader.implicitHeight + 2 * Theme.panelPadding * 0.75
            radius: Theme.radiusSmall
            color: Theme.surface
            border.color: Theme.border
            border.width: Theme.borderWidth

            Loader {
                id: loader
                x: Theme.panelPadding * 0.75
                y: Theme.panelPadding * 0.75
                width: frame.width - 2 * x
                source: Qt.resolvedUrl("../" + root.cards[frame.modelData])
            }
        }
    }

    Item {
        Layout.fillHeight: true
    }
}
