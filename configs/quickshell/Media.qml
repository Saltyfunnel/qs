import Quickshell
import Quickshell.Services.Mpris
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    property var player: Mpris.players.values[0] ?? null

    readonly property bool hasMedia: player !== null && (player.trackTitle !== "" || player.playbackState === MprisPlaybackState.Playing)

    visible: hasMedia
    implicitWidth: hasMedia ? labelRow.implicitWidth : 0
    implicitHeight: hasMedia ? labelRow.implicitHeight : 0

    RowLayout {
        id: labelRow
        spacing: 6
        visible: root.hasMedia

        Text {
            text: "󰝚"
            color: Colors.c(0)
            font.pixelSize: 14
            font.family: "Hack Nerd Font"
        }
        Text {
            text: root.player ? (root.player.trackArtist || "") + " - " + (root.player.trackTitle || "") : ""
            color: Colors.c(0)
            font.pixelSize: 12
            font.family: "Hack Nerd Font"
            elide: Text.ElideRight
            width: Math.min(implicitWidth, 220)
        }
    }

    MouseArea {
        anchors.fill: parent
        enabled: root.hasMedia
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: (e) => {
            if (e.button === Qt.RightButton) {
                if (root.player) root.player.togglePlaying()
            } else {
                bar.togglePopup(popup)
            }
        }
        onWheel: (e) => {
            if (!root.player) return
            if (e.angleDelta.y > 0) root.player.previous()
            else root.player.next()
        }
    }

    PopupWindow {
        id: popup
        visible: false
        anchor.item: root
        anchor.edges: Edges.Bottom | Edges.Left
        anchor.gravity: Edges.Bottom | Edges.Right
        anchor.margins.top: 8
        implicitWidth: 300
        implicitHeight: 380
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
                anchors.margins: 18
                spacing: 14

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    Text {
                        text: "󰝚"
                        color: Colors.c(1)
                        font.pixelSize: 20
                        font.family: "Hack Nerd Font"
                    }
                    ColumnLayout {
                        spacing: 2
                        Text {
                            text: "Media"
                            color: Colors.c(7)
                            font.bold: true
                            font.pixelSize: 15
                            font.family: "Hack Nerd Font"
                        }
                        Text {
                            text: root.player ? (root.player.identity || "PLAYER").toUpperCase() : "NO PLAYER"
                            color: Colors.c(8)
                            font.pixelSize: 10
                            font.bold: true
                            font.family: "Hack Nerd Font"
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: width
                    radius: 10
                    color: Colors.c(0)
                    clip: true

                    Image {
                        anchors.fill: parent
                        source: root.player && root.player.trackArtUrl ? root.player.trackArtUrl : ""
                        fillMode: Image.PreserveAspectCrop
                        visible: root.player && root.player.trackArtUrl && root.player.trackArtUrl.length > 0
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "󰝚"
                        color: Colors.c(8)
                        font.pixelSize: 48
                        font.family: "Hack Nerd Font"
                        visible: !(root.player && root.player.trackArtUrl && root.player.trackArtUrl.length > 0)
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    Text {
                        text: root.player ? (root.player.trackTitle || "Unknown title") : "Nothing playing"
                        color: Colors.c(7)
                        font.bold: true
                        font.pixelSize: 14
                        font.family: "Hack Nerd Font"
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                    Text {
                        text: root.player ? (root.player.trackArtist || "") : ""
                        color: Colors.c(8)
                        font.pixelSize: 11
                        font.family: "Hack Nerd Font"
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                }

                Item {
                    Layout.fillWidth: true
                    height: 6

                    Rectangle {
                        anchors.fill: parent
                        radius: 3
                        color: Colors.c(0)
                    }
                    Rectangle {
                        width: (root.player && root.player.length > 0)
                               ? parent.width * (root.player.position / root.player.length)
                               : 0
                        height: parent.height
                        radius: 3
                        color: Colors.c(1)
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: (e) => {
                            if (root.player && root.player.length > 0) {
                                root.player.position = (e.x / width) * root.player.length
                            }
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 28

                    Text {
                        text: "󰒮"
                        color: Colors.c(7)
                        font.pixelSize: 20
                        font.family: "Hack Nerd Font"
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: if (root.player) root.player.previous() }
                    }
                    Text {
                        text: root.player && root.player.playbackState === MprisPlaybackState.Playing ? "󰏤" : "󰐊"
                        color: Colors.c(1)
                        font.pixelSize: 28
                        font.family: "Hack Nerd Font"
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: if (root.player) root.player.togglePlaying() }
                    }
                    Text {
                        text: "󰒭"
                        color: Colors.c(7)
                        font.pixelSize: 20
                        font.family: "Hack Nerd Font"
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: if (root.player) root.player.next() }
                    }
                }
            }
        }
    }
}
