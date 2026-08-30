import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

Item {
    id: btRoot

    property bool btPowered: true
    property var connectedDevices: []
    property var availableDevices: []

    implicitWidth: 28
    implicitHeight: 28

    Process {
        id: btPowerFetcher
        command: ["sh", "-c", "bluetoothctl show | grep -q 'Powered: yes' && echo yes || echo no"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: btRoot.btPowered = text.trim() === "yes"
        }
    }

    Process {
        id: btDevicesFetcher
        command: ["sh", "-c", "bluetoothctl devices"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = text.trim().split("\n").filter(l => l.length > 0)
                var avail = []
                for (var i = 0; i < lines.length; i++) {
                    var parts = lines[i].trim().split(/\s+/)
                    if (parts.length >= 3 && parts[0] === "Device") {
                        var mac = parts[1]
                        var name = parts.slice(2).join(" ")
                        avail.push({ "mac": mac, "name": name })
                    }
                }
                btRoot.availableDevices = avail
            }
        }
    }

    Process {
        id: btConnectedFetcher
        command: ["sh", "-c", "bluetoothctl info | grep -E 'Device|Connected:'"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = text.trim().split("\n")
                var conn = []
                var currentMac = ""
                var currentName = ""

                for (var i = 0; i < lines.length; i++) {
                    var line = lines[i].trim()
                    if (line.startsWith("Device")) {
                        var parts = line.split(/\s+/)
                        currentMac = parts[1]
                        currentName = parts.slice(2).join(" ")
                    } else if (line.indexOf("Connected: yes") !== -1 && currentMac !== "") {
                        conn.push({ "mac": currentMac, "name": currentName })
                    }
                }
                btRoot.connectedDevices = conn
            }
        }
    }

    Process {
        id: toggleBtProcess
    }

    Process {
        id: connectProcess
    }

    Timer {
        interval: 4000
        running: true
        repeat: true
        onTriggered: {
            btPowerFetcher.running = false
            btPowerFetcher.running = true
            btDevicesFetcher.running = false
            btDevicesFetcher.running = true
            btConnectedFetcher.running = false
            btConnectedFetcher.running = true
        }
    }

    Text {
        anchors.centerIn: parent
        text: "󰂯"
        color: Colors.c(0)
        font.pixelSize: 14
        font.family: "Hack Nerd Font"
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: bar.togglePopup(btPopup)
    }

    PopupWindow {
        id: btPopup
        visible: false
        anchor.item: btRoot
        anchor.rect.x: -160
        anchor.rect.y: btRoot.height + 8

        grabFocus: true

        implicitWidth: 320
        implicitHeight: Math.max(160, layoutContent.implicitHeight + 32)
        color: "transparent"

        onVisibleChanged: {
            if (visible) {
                contentRoot.opacity = 0
                contentRoot.scale = 0.94
                Qt.callLater(function() {
                    contentRoot.opacity = 1
                    contentRoot.scale = 1
                })
            }
        }

        Rectangle {
            id: contentRoot
            anchors.fill: parent
            radius: 12
            color: Colors.bg()
            border.color: Colors.c(1)
            border.width: 2

            opacity: 0
            scale: 0.94
            transformOrigin: Item.Center

            Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
            Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

            ColumnLayout {
                id: layoutContent
                anchors.fill: parent
                anchors.margins: 16
                spacing: 12

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    Text {
                        text: "󰂯"
                        color: Colors.c(1)
                        font.pixelSize: 28
                        font.family: "Hack Nerd Font"
                    }

                    ColumnLayout {
                        spacing: 2
                        Text {
                            text: "Bluetooth"
                            color: Colors.c(7)
                            font.bold: true
                            font.pixelSize: 16
                            font.family: "Hack Nerd Font"
                        }
                        Text {
                            text: "POLISHING PACKETS"
                            color: Colors.c(8)
                            font.pixelSize: 9
                            font.bold: true
                            font.family: "Hack Nerd Font"
                        }
                    }

                    Item { Layout.fillWidth: true }

                    Rectangle {
                        id: toggleSwitch
                        implicitWidth: 44
                        implicitHeight: 22
                        radius: 11
                        color: btRoot.btPowered ? Colors.c(1) : Qt.rgba(0, 0, 0, 0.35)
                        border.color: btRoot.btPowered ? Colors.c(1) : Colors.c(8)
                        border.width: 1

                        Behavior on color {
                            ColorAnimation { duration: 150 }
                        }

                        Rectangle {
                            id: switchHandle
                            x: btRoot.btPowered ? parent.width - width - 3 : 3
                            y: 3
                            width: 16
                            height: 16
                            radius: 8
                            color: btRoot.btPowered ? Colors.bg() : Colors.c(7)

                            Behavior on x {
                                NumberAnimation { duration: 150; easing.type: Easing.InOutQuad }
                            }
                            Behavior on color {
                                ColorAnimation { duration: 150 }
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                var cmd = btRoot.btPowered ? "bluetoothctl power off" : "bluetoothctl power on"
                                toggleBtProcess.command = ["sh", "-c", cmd]
                                toggleBtProcess.running = true
                                btRoot.btPowered = !btRoot.btPowered
                            }
                        }
                    }
                }

                Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Colors.c(8) }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 6
                    visible: btRoot.connectedDevices.length > 0

                    Text {
                        text: "CONNECTED"
                        color: Colors.c(8)
                        font.pixelSize: 10
                        font.bold: true
                        font.family: "Hack Nerd Font"
                    }

                    Repeater {
                        model: btRoot.connectedDevices

                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: 36
                            radius: 6
                            color: Colors.c(8)

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 8
                                spacing: 8

                                Text { text: "󰂱"; color: Colors.c(7); font.pixelSize: 14; font.family: "Hack Nerd Font" }
                                Text { text: modelData.name; color: Colors.c(7); font.bold: true; font.pixelSize: 12; font.family: "Hack Nerd Font" }
                                Item { Layout.fillWidth: true }

                                Text {
                                    text: "Disconnect"
                                    color: Colors.c(1)
                                    font.pixelSize: 10
                                    font.family: "Hack Nerd Font"

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            connectProcess.command = ["bluetoothctl", "disconnect", modelData.mac]
                                            connectProcess.running = true
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Text {
                        text: "AVAILABLE"
                        color: Colors.c(8)
                        font.pixelSize: 10
                        font.bold: true
                        font.family: "Hack Nerd Font"
                    }

                    Repeater {
                        model: btRoot.availableDevices

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 12

                            Text {
                                text: "󰂯"
                                color: Colors.c(8)
                                font.pixelSize: 14
                                font.family: "Hack Nerd Font"
                            }

                            Text {
                                text: modelData.name
                                color: Colors.c(7)
                                font.pixelSize: 12
                                font.family: "Hack Nerd Font"
                            }

                            Item { Layout.fillWidth: true }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    connectProcess.command = ["bluetoothctl", "connect", modelData.mac]
                                    connectProcess.running = true
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
