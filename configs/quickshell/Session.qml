import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

Item {
    id: root
    implicitWidth: 28
    implicitHeight: 28

    // Trigger Icon for Bar
    Text {
        id: label
        anchors.centerIn: parent
        text: "󰐥"
        color: Colors.c(0)
        font.pixelSize: 14
        font.family: "Hack Nerd Font"
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            sessionModal.showConfirm = false
            sessionModal.visible = !sessionModal.visible
        }
    }

    // Central Screen Overlay Modal
    PanelWindow {
        id: sessionModal
        visible: false

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        color: "transparent"

        property string confirmCmd: ""
        property bool showConfirm: false

        function confirm(action, cmd) {
            confirmLabel.text = action
            confirmCmd = cmd
            showConfirm = true
        }

        // Dark dim backdrop - click outside to dismiss
        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(0, 0, 0, 0.6)

            MouseArea {
                anchors.fill: parent
                onClicked: sessionModal.visible = false
            }
        }

        // Central Selector Box
        Rectangle {
            anchors.centerIn: parent
            width: sessionModal.showConfirm ? 360 : 520
            height: sessionModal.showConfirm ? 160 : 140
            radius: 16
            color: Colors.bg()
            border.color: Colors.c(1)
            border.width: 2

            // Prevent background click-through
            MouseArea { anchors.fill: parent }

            // ---- Icon Grid Only ----
            RowLayout {
                anchors.fill: parent
                anchors.margins: 20
                spacing: 12
                visible: !sessionModal.showConfirm

                Repeater {
                    model: [
                        { icon: "󰌾", label: "Lock", cmd: "loginctl lock-session", confirmLabel: "" },
                        { icon: "󰤄", label: "Suspend", cmd: "systemctl suspend", confirmLabel: "" },
                        { icon: "󰑓", label: "Reboot", cmd: "systemctl reboot", confirmLabel: "Reboot now?" },
                        { icon: "󰐥", label: "Shut Down", cmd: "systemctl poweroff", confirmLabel: "Shut down now?" },
                        { icon: "󰍃", label: "Log Out", cmd: "hyprctl dispatch 'hl.dsp.exit()'", confirmLabel: "Log out now?" }
                    ]

                    delegate: Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: 12
                        color: btnArea.containsMouse ? Qt.tint(Colors.bg(), Qt.rgba(1, 1, 1, 0.1)) : Colors.c(0)
                        border.color: btnArea.containsMouse ? Colors.c(1) : "transparent"
                        border.width: 1

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 8

                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: modelData.icon
                                color: Colors.c(1)
                                font.pixelSize: 28
                                font.family: "Hack Nerd Font"
                            }
                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: modelData.label
                                color: Colors.c(7)
                                font.pixelSize: 12
                                font.bold: true
                                font.family: "Hack Nerd Font"
                            }
                        }

                        MouseArea {
                            id: btnArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (modelData.confirmLabel.length > 0) {
                                    sessionModal.confirm(modelData.confirmLabel, modelData.cmd)
                                } else {
                                    Quickshell.execDetached(["bash", "-c", modelData.cmd])
                                    sessionModal.visible = false
                                }
                            }
                        }
                    }
                }
            }

            // ---- Confirmation View ----
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 20
                spacing: 16
                visible: sessionModal.showConfirm

                Text {
                    id: confirmLabel
                    text: ""
                    color: Colors.c(7)
                    font.bold: true
                    font.pixelSize: 16
                    font.family: "Hack Nerd Font"
                    Layout.alignment: Qt.AlignHCenter
                }

                Item { Layout.fillHeight: true }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 38
                        radius: 8
                        color: Colors.c(0)

                        Text {
                            anchors.centerIn: parent
                            text: "Cancel"
                            color: Colors.c(7)
                            font.pixelSize: 12
                            font.family: "Hack Nerd Font"
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: sessionModal.showConfirm = false
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 38
                        radius: 8
                        color: Colors.c(1)

                        Text {
                            anchors.centerIn: parent
                            text: "Confirm"
                            color: Colors.bg()
                            font.bold: true
                            font.pixelSize: 12
                            font.family: "Hack Nerd Font"
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                Quickshell.execDetached(["bash", "-c", sessionModal.confirmCmd])
                                sessionModal.showConfirm = false
                                sessionModal.visible = false
                            }
                        }
                    }
                }
            }
        }
    }
}
