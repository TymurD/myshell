import QtQuick
import QtQuick.Layouts
import qs.modules.settings
import qs.components
import qs.config
import qs.theme

// Edits several id lists side by side (e.g. bar.left / bar.center / bar.right) plus a
// "Hidden" column with the ids from `allIds` that are in no list.
//   ↑ ↓  reorder inside a column      ← →  move to the neighbouring column
//   eye-off  hide (remove from its list)   eye  show again (back where it was hidden from,
//   else the last column)
// Every action writes the changed list(s) through Config.set.
RowLayout {
    id: root

    property var columns: []   // [{ title, path }]
    property var allIds: []
    property real columnWidth: Theme.barHeight * 7
    readonly property real buttonSize: Theme.barHeight * 0.75

    // id → column index it was hidden from (this session only)
    property var hiddenFrom: ({})

    readonly property var lists: columns.map(c => Config.get(c.path) ?? [])
    readonly property var hidden: allIds.filter(id => !lists.some(l => l.includes(id)))

    function save(ci: int, list: var): void {
        Config.set(columns[ci].path, list);
    }

    function reorder(ci: int, i: int, d: int): void {
        const l = lists[ci].slice();
        const j = i + d;
        if (j < 0 || j >= l.length)
            return;
        [l[i], l[j]] = [l[j], l[i]];
        save(ci, l);
    }

    function shift(ci: int, i: int, d: int): void {
        const cj = ci + d;
        if (cj < 0 || cj >= columns.length)
            return;
        const from = lists[ci].slice();
        const to = lists[cj].slice();
        const [id] = from.splice(i, 1);
        to.splice(Math.min(i, to.length), 0, id);
        save(ci, from);
        save(cj, to);
    }

    function hide(ci: int, i: int): void {
        const l = lists[ci].slice();
        const [id] = l.splice(i, 1);
        const h = Object.assign({}, hiddenFrom);
        h[id] = ci;
        hiddenFrom = h;
        save(ci, l);
    }

    function show(id: string): void {
        const ci = hiddenFrom[id] ?? columns.length - 1;
        save(ci, lists[ci].concat([id]));
    }

    spacing: Theme.panelGap

    Repeater {
        model: root.columns.length

        Column {
            id: col
            required property int index
            readonly property int ci: index
            readonly property var items: root.lists[ci] ?? []

            Layout.alignment: Qt.AlignTop
            Layout.preferredWidth: root.columnWidth
            spacing: Theme.panelGap / 2

            StyledText {
                text: root.columns[col.ci].title
                color: Theme.textMuted
                font.pixelSize: Theme.fontSizeSmall
            }

            Repeater {
                model: col.items

                ItemRow {
                    required property string modelData
                    required property int index
                    width: root.columnWidth
                    name: modelData

                    IconButton {
                        size: root.buttonSize
                        icon: 0xF005D // nf-md-arrow_up
                        enabled: index > 0
                        onClicked: root.reorder(col.ci, index, -1)
                    }
                    IconButton {
                        size: root.buttonSize
                        icon: 0xF0045 // nf-md-arrow_down
                        enabled: index < col.items.length - 1
                        onClicked: root.reorder(col.ci, index, 1)
                    }
                    IconButton {
                        size: root.buttonSize
                        icon: 0xF004D // nf-md-arrow_left
                        enabled: col.ci > 0
                        onClicked: root.shift(col.ci, index, -1)
                    }
                    IconButton {
                        size: root.buttonSize
                        icon: 0xF0054 // nf-md-arrow_right
                        enabled: col.ci < root.columns.length - 1
                        onClicked: root.shift(col.ci, index, 1)
                    }
                    IconButton {
                        size: root.buttonSize
                        icon: 0xF0209 // nf-md-eye_off
                        onClicked: root.hide(col.ci, index)
                    }
                }
            }

            StyledText {
                visible: col.items.length === 0
                text: "empty"
                color: Theme.textFaint
                font.pixelSize: Theme.fontSizeSmall
            }
        }
    }

    Column {
        Layout.alignment: Qt.AlignTop
        Layout.preferredWidth: root.columnWidth * 0.7
        spacing: Theme.panelGap / 2

        StyledText {
            text: "Hidden"
            color: Theme.textMuted
            font.pixelSize: Theme.fontSizeSmall
        }

        Repeater {
            model: root.hidden

            ItemRow {
                required property string modelData
                width: root.columnWidth * 0.7
                name: modelData
                dim: true

                IconButton {
                    size: root.buttonSize
                    icon: 0xF0208 // nf-md-eye
                    onClicked: root.show(modelData)
                }
            }
        }

        StyledText {
            visible: root.hidden.length === 0
            text: "none"
            color: Theme.textFaint
            font.pixelSize: Theme.fontSizeSmall
        }
    }
}
