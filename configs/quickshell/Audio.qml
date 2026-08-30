import Quickshell
import Quickshell.Services.Pipewire
import QtQuick
import QtQuick.Layouts

Item {
    id: audioRoot
    property var sink: Pipewire.defaultAudioSink
    property var source: Pipewire.defaultAudioSource

    implicitWidth: 28
    implicitHeight: 28

    PwObjectTracker { objects: [audioRoot.sink, audioRoot.source] }

    Text {
        anchors.centerIn: parent
        text: {
            if (!audioRoot.sink || !audioRoot.sink.audio) return "󰓄"
            var vol = Math.round(audioRoot.sink.audio.volume * 100)
            return audioRoot.sink.audio.muted ? "󰝟" : (vol > 50 ? "󰕾" : "󰖀")
        }
        color: Colors.c(0)
        font.pixelSize: 14
        font.family: "Hack Nerd Font"
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: (mouse) => {
            if (mouse.button === Qt.RightButton) {
                if (audioRoot.sink && audioRoot.sink.audio) {
                    audioRoot.sink.audio.muted = !audioRoot.sink.audio.muted
                }
            } else {
                bar.togglePopup(audioPopup)
            }
        }
    }

    PopupWindow {
        id: audioPopup
        visible: false
        anchor.item: audioRoot
        anchor.rect.x: -240
        anchor.rect.y: audioRoot.height + 8

        implicitWidth: 300
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
                anchors.margins: 14
                spacing: 10

                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        text: "󰕾 Speaker Volume"
                        color: Colors.c(7)
                        font.bold: true
                        font.pixelSize: 13
                        font.family: "Hack Nerd Font"
                    }
                    Item { Layout.fillWidth: true }
                    Text {
                        text: audioRoot.sink && audioRoot.sink.audio ? Math.round(audioRoot.sink.audio.volume * 100) + "%" : "0%"
                        color: Colors.c(1)
                        font.bold: true
                        font.pixelSize: 12
                        font.family: "Hack Nerd Font"
                    }
                }

                Rectangle {
                    id: sinkTrack
                    Layout.fillWidth: true
                    implicitHeight: 8
                    radius: 4
                    color: Colors.c(8)

                    Rectangle {
                        width: parent.width * (audioRoot.sink && audioRoot.sink.audio ? audioRoot.sink.audio.volume : 0)
                        height: parent.height
                        radius: 4
                        color: Colors.c(1)
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onPositionChanged: (mouse) => {
                            if (audioRoot.sink && audioRoot.sink.audio) {
                                var v = Math.max(0, Math.min(1, mouse.x / width))
                                audioRoot.sink.audio.volume = v
                            }
                        }
                        onPressed: (mouse) => {
                            if (audioRoot.sink && audioRoot.sink.audio) {
                                var v = Math.max(0, Math.min(1, mouse.x / width))
                                audioRoot.sink.audio.volume = v
                            }
                        }
                    }
                }

                Rectangle { Layout.fillWidth: true; height: 1; color: Colors.c(8) }

                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        text: "󰍬 Mic Volume"
                        color: Colors.c(7)
                        font.bold: true
                        font.pixelSize: 13
                        font.family: "Hack Nerd Font"
                    }
                    Item { Layout.fillWidth: true }
                    Text {
                        text: audioRoot.source && audioRoot.source.audio ? Math.round(audioRoot.source.audio.volume * 100) + "%" : "0%"
                        color: Colors.c(1)
                        font.bold: true
                        font.pixelSize: 12
                        font.family: "Hack Nerd Font"
                    }
                }

                Rectangle {
                    id: sourceTrack
                    Layout.fillWidth: true
                    implicitHeight: 8
                    radius: 4
                    color: Colors.c(8)

                    Rectangle {
                        width: parent.width * (audioRoot.source && audioRoot.source.audio ? audioRoot.source.audio.volume : 0)
                        height: parent.height
                        radius: 4
                        color: Colors.c(1)
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onPositionChanged: (mouse) => {
                            if (audioRoot.source && audioRoot.source.audio) {
                                var v = Math.max(0, Math.min(1, mouse.x / width))
                                audioRoot.source.audio.volume = v
                            }
                        }
                        onPressed: (mouse) => {
                            if (audioRoot.source && audioRoot.source.audio) {
                                var v = Math.max(0, Math.min(1, mouse.x / width))
                                audioRoot.source.audio.volume = v
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 30
                    radius: 6
                    color: Colors.c(8)
                    Text {
                        anchors.centerIn: parent
                        text: "󰓄 Open Volume Control (pavucontrol)"
                        color: Colors.c(7)
                        font.pixelSize: 11
                        font.family: "Hack Nerd Font"
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Quickshell.execDetached(["pavucontrol"])
                    }
                }
            }
        }
    }
}
