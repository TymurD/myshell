import QtQuick
import QtQuick.Layouts
import qs.components
import qs.services
import qs.theme

// Expanded network: current connection + details, live ↓↑, wired device,
// wifi toggle and network list (connect / password / disconnect / forget).
PanelSurface {
    id: root

    readonly property int rowHeight: 44
    readonly property int maxRows: 6

    // Network name whose row is expanded (password field or actions). While a row is
    // expanded the list order is frozen so the row doesn't move under the cursor.
    property string expandedName: ""
    property var nets: []

    implicitWidth: 420
    implicitHeight: col.implicitHeight + 2 * Theme.panelPadding

    Binding {
        target: root
        property: "nets"
        value: Network.sortedNetworks
        when: root.expandedName === ""
        restoreMode: Binding.RestoreNone
    }

    component SmallText: StyledText {
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.textDim
    }

    component TextButton: MouseArea {
        id: tb
        property string label
        property int code: 0
        property bool danger: false
        property bool filled: false

        implicitWidth: tbRow.implicitWidth + 24
        implicitHeight: 30
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        opacity: enabled ? 1 : 0.4

        Rectangle {
            anchors.fill: parent
            radius: Theme.radiusSmall
            color: tb.filled ? Theme.accent : tb.containsMouse ? Theme.surfaceHover : Theme.surface
            border.color: tb.danger && tb.containsMouse ? Theme.urgent : tb.filled ? Theme.accent : Theme.border
            border.width: Theme.borderWidth
            Behavior on color {
                ColorAnimation {
                    duration: Anim.fast
                }
            }
        }
        Row {
            id: tbRow
            anchors.centerIn: parent
            spacing: 6
            Icon {
                visible: tb.code !== 0
                code: tb.code
                font.pixelSize: Theme.fontSizeSmall
                color: tb.filled ? Theme.bgSolid : tb.danger ? Theme.urgent : Theme.text
            }
            StyledText {
                text: tb.label
                font.pixelSize: Theme.fontSizeSmall
                color: tb.filled ? Theme.bgSolid : tb.danger ? Theme.urgent : Theme.text
            }
        }
    }

    component Toggle: MouseArea {
        id: tg
        property bool checked

        implicitWidth: 44
        implicitHeight: 24
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        opacity: enabled ? 1 : 0.4

        Rectangle {
            anchors.fill: parent
            radius: height / 2
            color: tg.checked ? Theme.accent : Theme.surface
            border.color: tg.checked ? Theme.accent : Theme.borderStrong
            border.width: Theme.borderWidth
            Behavior on color {
                ColorAnimation {
                    duration: Anim.fast
                }
            }
            Rectangle {
                width: parent.height - 6
                height: width
                radius: width / 2
                anchors.verticalCenter: parent.verticalCenter
                x: tg.checked ? parent.width - width - 3 : 3
                color: tg.checked ? Theme.bgSolid : Theme.textDim
                Behavior on x {
                    NumberAnimation {
                        duration: Anim.fast
                        easing.type: Anim.standard
                    }
                }
            }
        }
    }

    ColumnLayout {
        id: col
        anchors.fill: parent
        anchors.margins: Theme.panelPadding
        spacing: 12

        // ---- header: current connection ----
        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            Icon {
                code: Network.icon()
                font.pixelSize: Theme.fontSizeXL
                color: Network.connected ? Theme.text : Theme.textDim
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                StyledText {
                    Layout.fillWidth: true
                    text: Network.name
                    font.pixelSize: Theme.fontSizeLarge
                    elide: Text.ElideRight
                }
                SmallText {
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    text: Network.connected ? [Network.kind === "wired" ? "Ethernet" : "Wi-Fi", Network.iface, Network.ip].filter(s => s).join("  ·  ") : Network.wifiHardwareEnabled ? "Not connected" : "Wi-Fi blocked by hardware switch"
                }
            }
        }

        // details
        GridLayout {
            Layout.fillWidth: true
            visible: Network.connected
            columns: 2
            rowSpacing: 4
            columnSpacing: 12

            component Key: SmallText {}
            component Val: StyledText {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignRight
                font.pixelSize: Theme.fontSizeSmall
                elide: Text.ElideLeft
            }

            Key {
                text: "Throughput"
            }
            Val {
                text: "↓ " + Network.formatRate(Network.rxRate) + "/s   ↑ " + Network.formatRate(Network.txRate) + "/s"
            }
            Key {
                visible: Network.kind === "wifi"
                text: "Signal"
            }
            Val {
                visible: Network.kind === "wifi"
                text: Math.round(Network.strength * 100) + "%" + (Network.securityText(Network.wifiNetwork) ? "  ·  " + Network.securityText(Network.wifiNetwork) : "")
            }
            Key {
                visible: Network.gateway !== ""
                text: "Gateway"
            }
            Val {
                visible: Network.gateway !== ""
                text: Network.gateway
            }
            Key {
                visible: Network.dns !== ""
                text: "DNS"
            }
            Val {
                visible: Network.dns !== ""
                text: Network.dns
            }
        }

        // ---- wired ----
        Rectangle {
            Layout.fillWidth: true
            visible: Network.wiredDevice !== null
            implicitHeight: wiredRow.implicitHeight + 16
            radius: Theme.radiusSmall
            color: Theme.surface
            border.color: Theme.border
            border.width: Theme.borderWidth

            RowLayout {
                id: wiredRow
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                spacing: 10

                Icon {
                    code: 0xF0200
                    color: Network.wiredDevice?.connected ? Theme.text : Theme.textMuted
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    StyledText {
                        text: "Ethernet  ·  " + (Network.wiredDevice?.name ?? "")
                        font.pixelSize: Theme.fontSizeSmall
                    }
                    SmallText {
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                        text: {
                            const d = Network.wiredDevice;
                            if (!d)
                                return "";
                            if (!d.hasLink)
                                return "Cable unplugged";
                            const speed = d.linkSpeed > 0 ? (d.linkSpeed >= 1000 ? (d.linkSpeed / 1000) + " Gb/s" : d.linkSpeed + " Mb/s") : "";
                            return [Network.stateText(d.state), speed].filter(s => s).join("  ·  ");
                        }
                    }
                }
            }
        }

        // ---- wifi header + toggle ----
        RowLayout {
            Layout.fillWidth: true
            visible: Network.wifi !== null
            spacing: 8

            StyledText {
                text: "Wi-Fi"
            }
            SmallText {
                Layout.fillWidth: true
                text: Network.wifiEnabled ? (Network.wifi?.scannerEnabled ? "scanning…" : "") : "off"
                color: Theme.textMuted
            }
            Toggle {
                checked: Network.wifiEnabled
                enabled: Network.wifiHardwareEnabled
                onClicked: Network.setWifiEnabled(!Network.wifiEnabled)
            }
        }

        // ---- wifi list ----
        ListView {
            id: list
            Layout.fillWidth: true
            visible: Network.wifi !== null && Network.wifiEnabled
            implicitHeight: Math.min(contentHeight, root.rowHeight * root.maxRows + 60)
            clip: true
            spacing: 2
            boundsBehavior: Flickable.StopAtBounds
            model: root.nets

            delegate: Item {
                id: row

                required property var modelData
                required property int index
                readonly property var net: modelData
                readonly property bool connected: net?.connected ?? false
                readonly property bool known: net?.known ?? false
                readonly property bool locked: Network.secured(net)
                readonly property bool busy: net?.stateChanging ?? false
                readonly property bool expanded: root.expandedName !== "" && root.expandedName === (net?.name ?? "")
                property string error: ""

                width: ListView.view.width
                height: root.rowHeight + (expanded ? extra.implicitHeight + 8 : 0)
                clip: true

                Behavior on height {
                    NumberAnimation {
                        duration: Anim.normal
                        easing.type: Anim.standard
                    }
                }

                Connections {
                    target: row.net
                    ignoreUnknownSignals: true
                    function onConnectionFailed(reason: int): void {
                        row.error = Network.failText(reason);
                    }
                    function onConnectedChanged(): void {
                        if (row.net?.connected) {
                            row.error = "";
                            if (row.expanded)
                                root.expandedName = "";
                        }
                    }
                }

                function activate(): void {
                    error = "";
                    if (connected || (locked && !known)) {
                        root.expandedName = expanded ? "" : net.name;
                        return;
                    }
                    root.expandedName = "";
                    Network.connectTo(net);
                }

                Rectangle {
                    anchors.fill: parent
                    radius: Theme.radiusSmall
                    color: row.expanded ? Theme.surface : head.containsMouse ? Theme.surfaceHover : "transparent"
                    border.color: row.expanded || row.connected ? Theme.border : "transparent"
                    border.width: Theme.borderWidth
                    Behavior on color {
                        ColorAnimation {
                            duration: Anim.fast
                        }
                    }
                }

                MouseArea {
                    id: head
                    width: parent.width
                    height: root.rowHeight
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: row.activate()

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        spacing: 10

                        Icon {
                            code: Network.strengthIcon(row.net?.signalStrength ?? 0, row.locked)
                            color: row.connected ? Theme.text : Theme.textDim
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0
                            StyledText {
                                Layout.fillWidth: true
                                text: row.net?.name ?? ""
                                font.pixelSize: Theme.fontSizeSmall
                                font.bold: row.connected
                                elide: Text.ElideRight
                            }
                            SmallText {
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                                color: row.error !== "" ? Theme.urgent : Theme.textMuted
                                text: row.error !== "" ? row.error : row.busy ? Network.stateText(row.net?.state ?? 0) : [row.connected ? "Connected" : row.known ? "Saved" : "", Network.securityText(row.net)].filter(s => s).join("  ·  ")
                            }
                        }
                        // forget a saved (not connected) network without expanding
                        MouseArea {
                            id: forgetBtn
                            visible: row.known && !row.connected && head.containsMouse
                            implicitWidth: 26
                            implicitHeight: 26
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Network.forget(row.net)
                            Icon {
                                anchors.centerIn: parent
                                code: 0xF09E7 // delete-outline
                                font.pixelSize: Theme.fontSizeSmall
                                color: forgetBtn.containsMouse ? Theme.urgent : Theme.textMuted
                            }
                        }
                        Icon {
                            visible: row.connected || (row.known && !head.containsMouse)
                            code: row.connected ? 0xF012C : 0xF00C1 // check / bookmark-check (saved)
                            font.pixelSize: Theme.fontSizeSmall
                            color: row.connected ? Theme.accent : Theme.textMuted
                        }
                    }
                }

                // expanded part: password field (secured unknown) or actions (connected)
                Item {
                    id: extra
                    y: root.rowHeight
                    width: parent.width
                    implicitHeight: row.connected ? actions.implicitHeight : pskRow.implicitHeight
                    visible: row.expanded

                    RowLayout {
                        id: actions
                        visible: row.connected
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        spacing: 8

                        Item {
                            Layout.fillWidth: true
                        }
                        TextButton {
                            label: "Disconnect"
                            code: 0xF0338
                            onClicked: {
                                root.expandedName = "";
                                Network.disconnectFrom(row.net);
                            }
                        }
                        TextButton {
                            label: "Forget"
                            code: 0xF09E7
                            danger: true
                            onClicked: {
                                root.expandedName = "";
                                Network.forget(row.net);
                            }
                        }
                    }

                    RowLayout {
                        id: pskRow
                        visible: !row.connected
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        spacing: 8

                        function submit(): void {
                            if (psk.text.length === 0)
                                return;
                            Network.connectWithPsk(row.net, psk.text);
                            psk.text = "";
                            root.expandedName = "";
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: 30
                            radius: Theme.radiusSmall
                            color: Theme.bgSolid
                            border.color: psk.activeFocus ? Theme.borderStrong : Theme.border
                            border.width: Theme.borderWidth

                            TextInput {
                                id: psk
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 34
                                verticalAlignment: TextInput.AlignVCenter
                                color: Theme.text
                                selectionColor: Theme.accent
                                selectedTextColor: Theme.bgSolid
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeSmall
                                echoMode: reveal.shown ? TextInput.Normal : TextInput.Password
                                clip: true
                                onAccepted: pskRow.submit()
                                Keys.onEscapePressed: {
                                    text = "";
                                    root.expandedName = "";
                                }

                                SmallText {
                                    anchors.fill: parent
                                    visible: psk.text === ""
                                    text: "Password"
                                    color: Theme.textMuted
                                }
                            }
                            MouseArea {
                                id: reveal
                                property bool shown: false
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                width: 30
                                height: parent.height
                                cursorShape: Qt.PointingHandCursor
                                onClicked: shown = !shown
                                Icon {
                                    anchors.centerIn: parent
                                    code: reveal.shown ? 0xF0209 : 0xF0208 // eye-off / eye
                                    font.pixelSize: Theme.fontSizeSmall
                                }
                            }
                        }
                        TextButton {
                            label: "Connect"
                            filled: true
                            enabled: psk.text.length > 0
                            onClicked: pskRow.submit()
                        }
                    }

                    onVisibleChanged: if (visible && !row.connected)
                        psk.forceActiveFocus()
                }
            }
        }

        SmallText {
            visible: Network.wifi !== null && Network.wifiEnabled && root.nets.length === 0
            Layout.alignment: Qt.AlignHCenter
            text: "Looking for networks…"
            color: Theme.textMuted
        }
    }
}
