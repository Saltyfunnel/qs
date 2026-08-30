import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

Item {
    id: monitorRoot

    property int brightnessLevel: 100
    property string currentScale: "1"

    implicitWidth: 28
    implicitHeight: 28

    Process {
        id: getBrightnessProcess
        command: ["brightnessctl", "-m", "i"]
        running: true

        stdout: SplitParser {
            onRead: data => {
                var parts = data.split(",")
                if (parts.length >= 4) {
                    var percentageStr = parts[3].replace("%", "").trim()
                    monitorRoot.brightnessLevel = parseInt(percentageStr)
                }
            }
        }
    }

    Process {
        id: setBrightnessProcess
        function setLevel(val) {
            command = ["brightnessctl", "s", val + "%"]
            running = true
        }
    }

    Process {
        id: setScaleProcess
        function setScale(val) {
            command = ["hyprctl", "eval", "hl.monitor({ output = \"DP-1\", scale = " + val + " })"]
            running = true
        }
    }

    Text {
        anchors.centerIn: parent
        text: "󰍹"
        color: Colors.c(0)
        font.pixelSize: 14
        font.family: "Hack Nerd Font"
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: bar.togglePopup(monitorPopup)
    }

    PopupWindow {
        id: monitorPopup
        visible: false
        anchor.item: monitorRoot
        anchor.edges: Edges.Bottom | Edges.Left
        anchor.gravity: Edges.Bottom | Edges.Right
        anchor.margins.top: 8

        grabFocus: true

        implicitWidth: 320
        implicitHeight: 220
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
                anchors.fill: parent
                anchors.margins: 16
                spacing: 12

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    Text {
                        text: "󰍹"
                        color: Colors.c(1)
                        font.pixelSize: 32
                        font.family: "Hack Nerd Font"
                    }

                    ColumnLayout {
                        spacing: 2
                        Text {
                            text: "Display"
                            color: Colors.c(7)
                            font.bold: true
                            font.pixelSize: 16
                            font.family: "Hack Nerd Font"
                        }
                        Text {
                            text: "SUN BLAST"
                            color: Colors.c(8)
                            font.pixelSize: 10
                            font.bold: true
                            font.family: "Hack Nerd Font"
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 1
                    color: Colors.c(0)
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            text: "BRIGHTNESS"
                            color: Colors.c(8)
                            font.pixelSize: 10
                            font.bold: true
                            font.family: "Hack Nerd Font"
                        }
                        Item { Layout.fillWidth: true }
                        Text {
                            text: monitorRoot.brightnessLevel + "%"
                            color: Colors.c(7)
                            font.bold: true
                            font.pixelSize: 11
                            font.family: "Hack Nerd Font"
                        }
                    }

                    Slider {
                        id: brightnessSlider
                        Layout.fillWidth: true
                        from: 5
                        to: 100
                        value: monitorRoot.brightnessLevel

                        onMoved: {
                            monitorRoot.brightnessLevel = Math.round(value)
                            setBrightnessProcess.setLevel(monitorRoot.brightnessLevel)
                        }

                        background: Rectangle {
                            x: brightnessSlider.leftPadding
                            y: brightnessSlider.topPadding + brightnessSlider.availableHeight / 2 - height / 2
                            implicitWidth: 200
                            implicitHeight: 4
                            width: brightnessSlider.availableWidth
                            height: implicitHeight
                            radius: 2
                            color: Colors.c(0)

                            Rectangle {
                                width: brightnessSlider.visualPosition * parent.width
                                height: parent.height
                                color: Colors.c(1)
                                radius: 2
                            }
                        }

                        handle: Rectangle {
                            x: brightnessSlider.leftPadding + brightnessSlider.visualPosition * (brightnessSlider.availableWidth - width)
                            y: brightnessSlider.topPadding + brightnessSlider.availableHeight / 2 - height / 2
                            implicitWidth: 10
                            implicitHeight: 10
                            radius: 5
                            color: Colors.c(7)
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 1
                    color: Colors.c(0)
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Text {
                        text: "SCALE"
                        color: Colors.c(8)
                        font.pixelSize: 10
                        font.bold: true
                        font.family: "Hack Nerd Font"
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 4

                          Repeater {
                            model: ["1", "1.25", "1.6", "2"]

                            Rectangle {
                                Layout.fillWidth: true
                                implicitHeight: 30
                                radius: 4
                                color: monitorRoot.currentScale === modelData ? Colors.c(0) : "transparent"
                                border.color: monitorRoot.currentScale === modelData ? Colors.c(1) : Colors.c(8)
                                border.width: 1

                                Text {
                                    anchors.centerIn: parent
                                    text: modelData + "x"
                                    color: monitorRoot.currentScale === modelData ? Colors.c(7) : Colors.c(8)
                                    font.pixelSize: 12
                                    font.bold: true
                                    font.family: "Hack Nerd Font"
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        monitorRoot.currentScale = modelData
                                        setScaleProcess.setScale(modelData)
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
