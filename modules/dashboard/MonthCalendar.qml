import QtQuick
import QtQuick.Layouts
import qs.modules.dashboard
import qs.components
import qs.config
import qs.services
import qs.theme

// Month calendar: weekday header (configurable first day), today highlighted,
// adjacent-month days dimmed, prev/next, click the title (or middle-click) → today,
// mouse wheel flips months, optional ISO week numbers.
//
// settings.json → dashboard.weekStart: 0..6 (0 = Sunday) or "monday" | "sunday" | "saturday"
//                 dashboard.weekNumbers: bool (default true)
Item {
    id: root

    readonly property int weekStart: {
        const w = Config.dashboard?.weekStart ?? 1;
        if (typeof w === "number")
            return ((w % 7) + 7) % 7;
        const names = ["sunday", "monday", "tuesday", "wednesday", "thursday", "friday", "saturday"];
        const i = names.indexOf(String(w).toLowerCase());
        return i >= 0 ? i : 1;
    }
    readonly property bool weekNumbers: Config.dashboard?.weekNumbers ?? true
    property real cell: 40

    // Recomputed once per day, not every second.
    readonly property string todayKey: Time.format("yyyy-MM-dd")
    readonly property date today: new Date(Number(todayKey.slice(0, 4)), Number(todayKey.slice(5, 7)) - 1, Number(todayKey.slice(8, 10)))

    property int viewYear: today.getFullYear()
    property int viewMonth: today.getMonth()
    readonly property bool showingToday: viewYear === today.getFullYear() && viewMonth === today.getMonth()

    function goToday(): void {
        viewYear = today.getFullYear();
        viewMonth = today.getMonth();
    }
    function shift(n: int): void {
        const d = new Date(viewYear, viewMonth + n, 1);
        viewYear = d.getFullYear();
        viewMonth = d.getMonth();
    }

    // Snap back to the current month whenever the dashboard is shown again.
    onVisibleChanged: if (visible)
        goToday()
    onTodayKeyChanged: goToday()

    function isoWeek(d: date): int {
        const t = new Date(d.getFullYear(), d.getMonth(), d.getDate());
        t.setDate(t.getDate() + 3 - (t.getDay() + 6) % 7);   // Thursday of this ISO week
        const jan4 = new Date(t.getFullYear(), 0, 4);
        return 1 + Math.round(((t - jan4) / 86400000 - 3 + (jan4.getDay() + 6) % 7) / 7);
    }

    // 6 rows × 7 days
    readonly property var days: {
        const first = new Date(viewYear, viewMonth, 1);
        const lead = (first.getDay() - weekStart + 7) % 7;
        const out = [];
        for (let i = 0; i < 42; i++) {
            const d = new Date(viewYear, viewMonth, 1 - lead + i);
            out.push({
                date: d,
                day: d.getDate(),
                inMonth: d.getMonth() === viewMonth,
                isToday: d.getFullYear() === today.getFullYear() && d.getMonth() === today.getMonth() && d.getDate() === today.getDate(),
                weekend: d.getDay() === 0 || d.getDay() === 6
            });
        }
        return out;
    }
    readonly property var weeks: {
        const out = [];
        for (let r = 0; r < 6; r++) {
            // every row contains exactly one Thursday; its ISO week is the row's week
            const row = days.slice(r * 7, r * 7 + 7);
            out.push(isoWeek(row.find(x => x.date.getDay() === 4).date));
        }
        return out;
    }

    implicitWidth: (weekNumbers ? cell * 0.8 : 0) + 7 * cell
    implicitHeight: col.implicitHeight

    component NavButton: MouseArea {
        id: nav
        property int icon
        implicitWidth: 30
        implicitHeight: 30
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        Rectangle {
            anchors.fill: parent
            radius: height / 2
            color: nav.containsMouse ? Theme.surfaceHover : "transparent"
            Behavior on color {
                ColorAnimation {
                    duration: Anim.fast
                }
            }
        }
        Icon {
            anchors.centerIn: parent
            code: nav.icon
            color: Theme.text
        }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.MiddleButton
        onClicked: root.goToday()
        onWheel: wheel => root.shift(wheel.angleDelta.y > 0 ? -1 : 1)
    }

    ColumnLayout {
        id: col
        width: parent.width
        spacing: 6

        RowLayout {
            Layout.fillWidth: true
            spacing: 4

            NavButton {
                icon: 0xF0141
                onClicked: root.shift(-1)
            }
            MouseArea {
                Layout.fillWidth: true
                implicitHeight: 30
                hoverEnabled: true
                cursorShape: root.showingToday ? Qt.ArrowCursor : Qt.PointingHandCursor
                onClicked: root.goToday()
                StyledText {
                    anchors.centerIn: parent
                    text: Qt.locale().standaloneMonthName(root.viewMonth) + " " + root.viewYear
                    color: parent.containsMouse && !root.showingToday ? Theme.textDim : Theme.text
                }
            }
            NavButton {
                icon: 0xF0142
                onClicked: root.shift(1)
            }
        }

        GridLayout {
            columns: root.weekNumbers ? 8 : 7
            rowSpacing: 0
            columnSpacing: 0

            // header
            StyledText {
                visible: root.weekNumbers
                Layout.preferredWidth: root.cell * 0.8
                Layout.preferredHeight: root.cell * 0.7
                horizontalAlignment: Text.AlignHCenter
                text: "wk"
                color: Theme.textMuted
                font.pixelSize: Theme.fontSizeSmall
            }
            Repeater {
                model: 7
                StyledText {
                    required property int index
                    readonly property int dow: (root.weekStart + index) % 7
                    Layout.preferredWidth: root.cell
                    Layout.preferredHeight: root.cell * 0.7
                    horizontalAlignment: Text.AlignHCenter
                    text: Qt.locale().dayName(dow, Locale.ShortFormat).slice(0, 2)
                    color: dow === 0 || dow === 6 ? Theme.textMuted : Theme.textDim
                    font.pixelSize: Theme.fontSizeSmall
                }
            }

            // 6 weeks, emitted cell by cell (week number column first, if shown)
            Repeater {
                model: 6 * (root.weekNumbers ? 8 : 7)

                Item {
                    id: cellItem
                    required property int index
                    readonly property int cols: root.weekNumbers ? 8 : 7
                    readonly property int row: Math.floor(index / cols)
                    readonly property int colIdx: index % cols
                    readonly property bool isWeekCol: root.weekNumbers && colIdx === 0
                    readonly property var d: isWeekCol ? null : root.days[row * 7 + colIdx - (root.weekNumbers ? 1 : 0)]

                    Layout.preferredWidth: isWeekCol ? root.cell * 0.8 : root.cell
                    Layout.preferredHeight: root.cell

                    Rectangle {
                        visible: cellItem.d?.isToday ?? false
                        anchors.centerIn: parent
                        width: root.cell - 6
                        height: width
                        radius: width / 2
                        color: Theme.accent
                    }
                    StyledText {
                        anchors.centerIn: parent
                        text: cellItem.isWeekCol ? root.weeks[cellItem.row] : cellItem.d?.day ?? ""
                        font.pixelSize: cellItem.isWeekCol ? Theme.fontSizeSmall : Theme.fontSize
                        font.bold: cellItem.d?.isToday ?? false
                        color: cellItem.isWeekCol ? Theme.textMuted : cellItem.d?.isToday ? Theme.bgSolid : !cellItem.d?.inMonth ? Theme.textMuted : cellItem.d?.weekend ? Theme.textDim : Theme.text
                        opacity: !cellItem.isWeekCol && !cellItem.d?.inMonth ? 0.45 : 1
                    }
                }
            }
        }
    }
}
