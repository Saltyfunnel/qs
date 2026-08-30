import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

Item {
    id: systemInfoRoot

    implicitWidth: 28
    implicitHeight: 28

    property int cpuUsage: 0
    property int memUsage: 0
    property string memText: "0GB / 0GB"
    property int diskUsage: 0
    property string diskText: "0GB / 0GB"
    property string uptimeText: "0m"

    Timer {
        interval: 2000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (sysPopup.visible) {
                cpuProc.running = true
                memProc.running = true
                diskProc.running = true
                uptimeProc.running = true
            }
        }
    }

    Process {
        id: cpuProc
        command: ["bash", "-c", "top -bn1 | grep 'Cpu(s)' | sed 's/.*, *\\([0-9.]*\\)%* id.*/\\1/' | awk '{print 100 - $1}'"]
        stdout: StdioCollector {
            onStreamFinished: {
                var val = parseFloat(text.trim())
                systemInfoRoot.cpuUsage = isNaN(val) ? 0 : Math.round(val)
            }
        }
    }

    Process {
        id: memProc
        command: ["bash", "-c", "free -m | awk 'NR==2{printf \"%d %.2f %.2f\", $3*100/$2, $3/1024, $2/1024}'"]
        stdout: StdioCollector {
            onStreamFinished: {
                var parts = text.trim().split(" ")
                if (parts.length >= 3) {
                    systemInfoRoot.memUsage = parseInt(parts[0]) || 0
                    systemInfoRoot.memText = parseFloat(parts[1]).toFixed(1) + "G / " + parseFloat(parts[2]).toFixed(1) + "G"
                }
            }
        }
    }

    Process {
        id: diskProc
        command: ["bash", "-c", "df -h / | awk 'NR==2 {print $5, $3, $2}' | tr -d '%'"]
        stdout: StdioCollector {
            onStreamFinished: {
                var parts = text.trim().split(/\s+/)
                if (parts.length >= 3) {
                    systemInfoRoot.diskUsage = parseInt(parts[0]) || 0
                    systemInfoRoot.diskText = parts[1] + " / " + parts[2]
                }
            }
        }
    }

    Process {
        id: uptimeProc
        command: ["bash", "-c", "uptime -p | sed 's/up //'"]
        stdout: StdioCollector {
            onStreamFinished: {
                systemInfoRoot.uptimeText = text.trim() || "Unknown"
            }
        }
    }

    Text {
        anchors.centerIn: parent
        text: "\uF4BC"
        color: Colors.c(0)
        font.pixelSize: 14
        font.family: "Hack Nerd Font"
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            bar.togglePopup(sysPopup)
            if (sysPopup.visible) {
                cpuProc.running = true
                memProc.running = true
                diskProc.running = true
                uptimeProc.running = true
            }
        }
    }

    PopupWindow {
        id: sysPopup
        visible: false
        anchor.item: systemInfoRoot
        anchor.rect.x: (systemInfoRoot.implicitWidth - sysPopup.implicitWidth) / 2
        anchor.rect.y: systemInfoRoot.height + 8

        grabFocus: true
        implicitWidth: 300
        implicitHeight: 250
        color: "transparent"

        Rectangle {
            anchors.fill: parent
            radius: 10
            color: Colors.bg()
            border.color: Colors.c(1)
            border.width: 2
            clip: true

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 15
                spacing: 12

                RowLayout {
                    Layout.fillWidth: true

                    Text {
                        text: "System Information"
                        color: Colors.c(4)
                        font.pixelSize: 13
                        font.bold: true
                        font.family: "Hack Nerd Font"
                    }

                    Item { Layout.fillWidth: true }

                    Text {
                        text: "\uF017 " + systemInfoRoot.uptimeText
                        color: Colors.c(8)
                        font.pixelSize: 10
                        font.family: "Hack Nerd Font"
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 1
                    color: Qt.tint(Colors.c(8), Qt.rgba(0, 0, 0, 0.5))
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 14

                    Repeater {
                        model: [
                            { icon: "\uF4BC", label: "CPU", value: systemInfoRoot.cpuUsage + "%", pct: systemInfoRoot.cpuUsage },
                            { icon: "\uF085", label: "RAM", value: systemInfoRoot.memText, pct: systemInfoRoot.memUsage },
                            { icon: "\uF0A0", label: "DISK (/)", value: systemInfoRoot.diskText, pct: systemInfoRoot.diskUsage }
                        ]
                        delegate: RowLayout {
                            Layout.fillWidth: true
                            spacing: 12

                            Text {
                                text: modelData.icon
                                color: Colors.c(4)
                                font.pixelSize: 26
                                font.family: "Hack Nerd Font"
                                Layout.preferredWidth: 32
                                horizontalAlignment: Text.AlignHCenter
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 4

                                RowLayout {
                                    Layout.fillWidth: true
                                    Text {
                                        text: modelData.label
                                        color: Colors.c(7)
                                        font.pixelSize: 11
                                        font.bold: true
                                        font.family: "Hack Nerd Font"
                                    }
                                    Item { Layout.fillWidth: true }
                                    Text {
                                        text: modelData.value
                                        color: Colors.c(4)
                                        font.pixelSize: 11
                                        font.bold: true
                                        font.family: "Hack Nerd Font"
                                    }
                                }

                                Rectangle {
                                    Layout.fillWidth: true
                                    implicitHeight: 7
                                    radius: 4
                                    color: Qt.rgba(0, 0, 0, 0.3)

                                    Rectangle {
                                        width: parent.width * (modelData.pct / 100.0)
                                        height: parent.height
                                        radius: 4
                                        color: Colors.c(4)
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
