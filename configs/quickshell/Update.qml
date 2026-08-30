import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

Item {
    id: root
    property int count: 0
    property int pacmanCount: 0
    property int aurCount: 0

    // Keep item hidden and collapse dimensions to 0 when count is 0
    visible: count > 0
    implicitWidth: count > 0 ? 28 : 0
    implicitHeight: count > 0 ? 28 : 0

    Text {
        id: label
        anchors.centerIn: parent
        text: "\uF0AB " + root.count
        color: Colors.c(0)
        font.family: "Hack Nerd Font"
        font.pixelSize: 13
    }

    Process {
        id: proc
        command: ["bash", "-c", "checkupdates 2>/dev/null | wc -l; yay -Qua 2>/dev/null | wc -l"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split("\n")
                root.pacmanCount = parseInt(lines[0]) || 0
                root.aurCount = parseInt(lines[1]) || 0
                root.count = root.pacmanCount + root.aurCount
            }
        }
    }

    Timer {
        interval: 3600000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: proc.running = true
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onClicked: (e) => {
            if (e.button === Qt.RightButton) {
                proc.running = true
            } else {
                bar.togglePopup(popup)
            }
        }
    }

    PopupWindow {
        id: popup
        visible: false
        anchor.item: root
        anchor.rect.x: (root.implicitWidth - popup.implicitWidth) / 2
        anchor.rect.y: root.height + 8

        grabFocus: true
        implicitWidth: 260
        implicitHeight: mainLayout.implicitHeight + 32
        color: "transparent"

        Rectangle {
            anchors.fill: parent
            color: Colors.bg()
            border.color: Colors.c(1)
            border.width: 2
            radius: 12

            ColumnLayout {
                id: mainLayout
                anchors.fill: parent
                anchors.margins: 16
                spacing: 12

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    Text {
                        text: "\uF0AB"
                        color: Colors.c(4)
                        font.pixelSize: 20
                        font.family: "Hack Nerd Font"
                    }

                    ColumnLayout {
                        spacing: 2
                        Text {
                            text: "SYSTEM UPDATES"
                            color: Colors.c(7)
                            font.bold: true
                            font.pixelSize: 12
                            font.letterSpacing: 1.5
                            font.family: "Hack Nerd Font"
                            Layout.fillWidth: true
                        }
                        Text {
                            text: root.pacmanCount + " PACMAN · " + root.aurCount + " AUR PENDING"
                            color: Colors.c(8)
                            font.pixelSize: 9
                            font.letterSpacing: 1.2
                            font.family: "Hack Nerd Font"
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: Qt.tint(Colors.c(8), Qt.rgba(0, 0, 0, 0.5))
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 30
                    radius: 6
                    color: Colors.c(1)

                    Text {
                        anchors.centerIn: parent
                        text: "UPGRADE PACKAGES"
                        color: Colors.c(7)
                        font.pixelSize: 10
                        font.bold: true
                        font.letterSpacing: 1.2
                        font.family: "Hack Nerd Font"
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            popup.visible = false
                            Quickshell.execDetached(["kitty", "-e", "yay"])
                        }
                    }
                }

                Text {
                    text: "REFRESH COUNT"
                    color: Colors.c(8)
                    font.pixelSize: 9
                    font.letterSpacing: 1.0
                    font.family: "Hack Nerd Font"
                    Layout.alignment: Qt.AlignHCenter

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            proc.running = true
                        }
                    }
                }
            }
        }
    }
}
