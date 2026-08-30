import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import QtQuick
import QtQuick.Layouts

Item {
    id: powerRoot

    // Check if any UPower device is a battery
    readonly property bool hasBattery: UPower.devices.values.some(d => d.type === UPowerDeviceType.Battery) ||
                                      (dev !== null && dev.type === UPowerDeviceType.Battery)

    property var dev: UPower.displayDevice
    property int pct: dev && dev.percentage ? Math.round(dev.percentage * 100) : 100
    property bool charging: dev ? dev.state === UPowerDeviceState.Charging : false
    property string tagline: ["BURNING ELECTRONS", "GUZZLING VOLTS", "SIPPING JOULES", "DRAINING SLOWLY"][Math.floor(Math.random() * 4)]

    property string batterySize: "--"
    property string timeLeft: "--"
    property string chargeCycles: "--"
    property string wattage: "--"
    property string activeProfile: "balanced"

    visible: hasBattery
    implicitWidth: hasBattery ? 28 : 0
    implicitHeight: hasBattery ? 28 : 0

    Process {
        id: statsProc
        command: ["sh", "-c", "BAT=$(upower -e | grep -m1 'BAT'); upower -i \"$BAT\""]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.split("\n")
                for (const l of lines) {
                    const t = l.trim()
                    if (t.startsWith("energy-full:")) {
                        const m = t.match(/([\d.]+)\s*Wh/)
                        if (m) powerRoot.batterySize = Math.round(parseFloat(m[1])) + "Wh"
                    } else if (t.startsWith("time to empty:") || t.startsWith("time to full:")) {
                        powerRoot.timeLeft = t.split(":").slice(1).join(":").trim()
                    } else if (t.startsWith("charge-cycles:")) {
                        const v = t.split(":")[1].trim()
                        powerRoot.chargeCycles = v === "N/A" ? "--" : v
                    } else if (t.startsWith("energy-rate:")) {
                        const m = t.match(/([\d.]+)\s*W/)
                        if (m) powerRoot.wattage = parseFloat(m[1]).toFixed(1) + "W"
                    }
                }
            }
        }
    }

    Process {
        id: profileProc
        command: ["bash", "-c", "powerprofilesctl get"]
        stdout: StdioCollector { onStreamFinished: powerRoot.activeProfile = text.trim() }
    }
    Timer {
        interval: 15000;
        running: powerRoot.hasBattery;
        repeat: true;
        triggeredOnStart: true;
        onTriggered: profileProc.running = true
    }

    Text {
        id: batIcon
        anchors.centerIn: parent
        text: powerRoot.charging ? "󱐋" : "󰁹"
        color: powerRoot.pct <= 20 ? Colors.c(1) : Colors.c(7)
        font.pixelSize: 14
        font.family: "Hack Nerd Font"
    }

    MouseArea {
        anchors.fill: parent
        enabled: powerRoot.hasBattery
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            bar.togglePopup(powerPopup)
            statsProc.running = true
            profileProc.running = true
        }
    }

    PopupWindow {
        id: powerPopup
        visible: false
        anchor.item: powerRoot
        anchor.rect.x: -200
        anchor.rect.y: powerRoot.height + 8
        implicitWidth: 320
        implicitHeight: 240
        color: "transparent"

        Rectangle {
            anchors.fill: parent
            radius: 12
            color: Colors.bg()
            border.color: Colors.c(1)
            border.width: 2

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 12

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    Text {
                        text: powerRoot.charging ? "󱐋" : "󰁹"
                        color: Colors.c(0)
                        font.pixelSize: 28
                        font.family: "Hack Nerd Font"
                    }

                    ColumnLayout {
                        spacing: 2
                        Text {
                            text: "Battery"
                            color: Colors.foreground
                            font.bold: true
                            font.pixelSize: 16
                            font.family: "Hack Nerd Font"
                        }
                        Text {
                            text: powerRoot.tagline
                            color: Qt.tint(Colors.foreground, Qt.rgba(0,0,0,0.35))
                            font.pixelSize: 9
                            font.bold: true
                            font.family: "Hack Nerd Font"
                        }
                    }

                    Item { Layout.fillWidth: true }

                    Text {
                        text: powerRoot.pct + "%"
                        color: Colors.foreground
                        font.bold: true
                        font.pixelSize: 26
                        font.family: "Hack Nerd Font"
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 8
                    radius: 4
                    color: Qt.tint(Colors.background, Qt.rgba(1, 1, 1, 0.15))

                    Rectangle {
                        width: parent.width * (powerRoot.pct / 100)
                        height: parent.height
                        radius: 4
                        color: Colors.c(1)
                    }
                }

                GridLayout {
                    Layout.fillWidth: true
                    columns: 2
                    rowSpacing: 4
                    columnSpacing: 10

                    Text { text: "Battery size"; color: Qt.tint(Colors.foreground, Qt.rgba(0,0,0,0.35)); font.pixelSize: 11; font.family: "Hack Nerd Font" }
                    Text { text: powerRoot.batterySize; color: Colors.foreground; font.pixelSize: 11; font.bold: true; font.family: "Hack Nerd Font"; Layout.alignment: Qt.AlignRight }

                    Text { text: "Time left"; color: Qt.tint(Colors.foreground, Qt.rgba(0,0,0,0.35)); font.pixelSize: 11; font.family: "Hack Nerd Font" }
                    Text { text: powerRoot.timeLeft; color: Colors.foreground; font.pixelSize: 11; font.bold: true; font.family: "Hack Nerd Font"; Layout.alignment: Qt.AlignRight }

                    Text { text: "Charge cycles"; color: Qt.tint(Colors.foreground, Qt.rgba(0,0,0,0.35)); font.pixelSize: 11; font.family: "Hack Nerd Font" }
                    Text { text: powerRoot.chargeCycles; color: Colors.foreground; font.pixelSize: 11; font.bold: true; font.family: "Hack Nerd Font"; Layout.alignment: Qt.AlignRight }

                    Text { text: powerRoot.charging ? "Charging" : "Discharging"; color: Qt.tint(Colors.foreground, Qt.rgba(0,0,0,0.35)); font.pixelSize: 11; font.family: "Hack Nerd Font" }
                    Text { text: powerRoot.wattage; color: Colors.foreground; font.pixelSize: 11; font.bold: true; font.family: "Hack Nerd Font"; Layout.alignment: Qt.AlignRight }
                }

                Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Qt.tint(Colors.foreground, Qt.rgba(0,0,0,0.7)) }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    Text {
                        text: "POWER PROFILE"
                        color: Qt.tint(Colors.foreground, Qt.rgba(0,0,0,0.35))
                        font.pixelSize: 10
                        font.bold: true
                        font.family: "Hack Nerd Font"
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 4

                        Repeater {
                            model: [
                                { key: "power-saver", label: "Power-saver" },
                                { key: "balanced", label: "Balanced" },
                                { key: "performance", label: "Performance" }
                            ]

                            Rectangle {
                                Layout.fillWidth: true
                                implicitHeight: 32
                                radius: 4
                                color: powerRoot.activeProfile === modelData.key
                                       ? Qt.tint(Colors.background, Qt.rgba(1, 1, 1, 0.15))
                                       : "transparent"
                                border.color: powerRoot.activeProfile === modelData.key
                                              ? Colors.c(1)
                                              : Qt.tint(Colors.foreground, Qt.rgba(0, 0, 0, 0.6))
                                border.width: 1

                                Text {
                                    anchors.centerIn: parent
                                    text: modelData.label
                                    color: powerRoot.activeProfile === modelData.key
                                           ? Colors.foreground
                                           : Qt.tint(Colors.foreground, Qt.rgba(0, 0, 0, 0.35))
                                    font.pixelSize: 10
                                    font.bold: true
                                    font.family: "Hack Nerd Font"
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        Quickshell.execDetached(["powerprofilesctl", "set", modelData.key])
                                        powerRoot.activeProfile = modelData.key
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
