import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

Item {
    id: root
    implicitWidth: 28
    implicitHeight: 28

    Text {
        anchors.centerIn: parent
        text: "󰄀"
        color: Colors.c(0)
        font.pixelSize: 14
        font.family: "Hack Nerd Font"
    }

    function shoot(mode) {
        let cmd = ""
        const dir = "~/Pictures/Screenshots"
        const file = dir + "/screenshot_$(date +%Y%m%d_%H%M%S).png"

        if (mode === "full") {
            cmd = "mkdir -p " + dir + " && grim " + file + " && wl-copy < " + file + " && notify-send 'Screenshot' 'Full screen captured'"
        } else if (mode === "region") {
            cmd = "mkdir -p " + dir + " && grim -g \"$(slurp)\" " + file + " && wl-copy < " + file + " && notify-send 'Screenshot' 'Region captured'"
        } else if (mode === "window") {
            cmd = "mkdir -p " + dir + " && grim -g \"$(hyprctl activewindow -j | jq -r '.at[0],.at[1],.size[0],.size[1]' | paste -sd' ' | awk '{print $1\",\"$2\" \"$3\"x\"$4}')\" " + file + " && wl-copy < " + file + " && notify-send 'Screenshot' 'Window captured'"
        }

        Quickshell.execDetached(["bash", "-c", cmd])
        bar.closeActivePopup()
    }

    function shootDelayed() {
        bar.closeActivePopup()
        delayNotify.running = true
        delayTimer.running = true
    }

    Process {
        id: delayNotify
        command: ["notify-send", "Screenshot", "Capturing in 3 seconds…"]
    }

    Timer {
        id: delayTimer
        interval: 3000
        repeat: false
        onTriggered: {
            const dir = "~/Pictures/Screenshots"
            const file = dir + "/screenshot_$(date +%Y%m%d_%H%M%S).png"
            const cmd = "mkdir -p " + dir + " && grim " + file + " && wl-copy < " + file + " && notify-send 'Screenshot' 'Full screen captured'"
            Quickshell.execDetached(["bash", "-c", cmd])
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: bar.togglePopup(popup)
    }

    PopupWindow {
        id: popup
        visible: false
        anchor.item: root
        anchor.edges: Edges.Bottom | Edges.Right
        anchor.gravity: Edges.Bottom | Edges.Left
        anchor.margins.top: 8
        implicitWidth: 260
        implicitHeight: 270
        color: "transparent"

        Rectangle {
            anchors.fill: parent
            radius: 12
            color: Colors.bg()
            border.color: Colors.c(1)
            border.width: 2

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 18
                spacing: 14

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    Text {
                        text: "󰄀"
                        color: Colors.c(1)
                        font.pixelSize: 20
                        font.family: "Hack Nerd Font"
                    }

                    ColumnLayout {
                        spacing: 2
                        Text {
                            text: "Screenshot"
                            color: Colors.foreground
                            font.bold: true
                            font.pixelSize: 15
                            font.family: "Hack Nerd Font"
                        }
                        Text {
                            text: "CAPTURING PIXELS"
                            color: Colors.c(8)
                            font.pixelSize: 10
                            font.bold: true
                            font.family: "Hack Nerd Font"
                        }
                    }
                }

                Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Colors.c(8) }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    Repeater {
                        model: [
                            { key: "region", icon: "󰆞", label: "Select Region" },
                            { key: "window", icon: "󰖯", label: "Active Window" },
                            { key: "full", icon: "󰹑", label: "Full Screen" },
                            { key: "delayed", icon: "󰥔", label: "Full Screen (3s delay)" }
                        ]
                        delegate: Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: 40
                            radius: 8
                            color: rowArea.containsMouse ? Qt.tint(Colors.background, Qt.rgba(1, 1, 1, 0.1)) : Colors.c(0)

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 12
                                spacing: 10

                                Text {
                                    text: modelData.icon
                                    color: Colors.c(1)
                                    font.pixelSize: 16
                                    font.family: "Hack Nerd Font"
                                }
                                Text {
                                    text: modelData.label
                                    color: Colors.foreground
                                    font.pixelSize: 12
                                    font.family: "Hack Nerd Font"
                                }
                                Item { Layout.fillWidth: true }
                                Text {
                                    text: "󰅂"
                                    color: Colors.c(8)
                                    font.pixelSize: 12
                                    font.family: "Hack Nerd Font"
                                }
                            }

                            MouseArea {
                                id: rowArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (modelData.key === "delayed") root.shootDelayed()
                                    else root.shoot(modelData.key)
                                }
                            }
                        }
                    }
                }

                Item { Layout.fillHeight: true }

                Text {
                    text: "Saved to ~/Pictures/Screenshots"
                    color: Colors.c(8)
                    font.pixelSize: 9
                    font.family: "Hack Nerd Font"
                }
            }
        }
    }
}
