import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

Item {
    id: wallpaperRoot

    property string currentWallpaper: ""
    property var wallpaperList: []

    implicitWidth: 28
    implicitHeight: 28

    function rescanWallpapers() {
        folderScanner.rawOutput = ""
        folderScanner.running = false
        folderScanner.running = true
    }

    Process {
        id: folderScanner
        command: [
            "bash", "-c",
            "find \"$HOME/Pictures/Wallpapers\" -type f \\( -iname \"*.png\" -o -iname \"*.jpg\" -o -iname \"*.jpeg\" -o -iname \"*.webp\" \\) -printf \"%T@ %p\n\" 2>/dev/null | sort -nr | cut -d' ' -f2-"
        ]
        running: true

        property string rawOutput: ""

        stdout: SplitParser {
            onRead: data => {
                folderScanner.rawOutput += data + "\n"
            }
        }

        onExited: (code, status) => {
            if (folderScanner.rawOutput.trim().length > 0) {
                var lines = folderScanner.rawOutput.trim().split("\n").filter(l => l.length > 0)
                wallpaperRoot.wallpaperList = lines
                if (wallpaperRoot.currentWallpaper === "" && lines.length > 0) {
                    wallpaperRoot.currentWallpaper = lines[0]
                }
            } else {
                wallpaperRoot.wallpaperList = []
            }
        }
    }

    function setRandomWallpaper() {
        if (wallpaperRoot.wallpaperList.length === 0) return
        var randomIndex = Math.floor(Math.random() * wallpaperRoot.wallpaperList.length)
        var selected = wallpaperRoot.wallpaperList[randomIndex]
        applyWallpaper(selected)
    }

    function applyWallpaper(filePath) {
        wallpaperRoot.currentWallpaper = filePath
        wallpaperRunner.selectedPath = filePath
        wallpaperRunner.running = false
        wallpaperRunner.running = true
    }

    Process {
        id: wallpaperRunner
        property string selectedPath: ""

        command: [
            "bash", "-c",
            "~/.config/scripts/setwall.sh \"" + selectedPath + "\""
        ]
    }

    Text {
        anchors.centerIn: parent
        text: "\uF03E"
        color: Colors.c(0)
        font.pixelSize: 14
        font.family: "Hack Nerd Font"
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor

        onClicked: mouse => {
            if (mouse.button === Qt.RightButton) {
                wallpaperRoot.setRandomWallpaper()
            } else {
                bar.togglePopup(wallpaperPopup)
            }
        }
    }

    PopupWindow {
        id: wallpaperPopup
        visible: false
        anchor.window: bar
        anchor.rect.x: (bar.width - wallpaperPopup.implicitWidth) / 2
        anchor.rect.y: (bar.screen.height - wallpaperPopup.implicitHeight) / 2

        grabFocus: true
        implicitWidth: 900
        implicitHeight: 620
        color: "transparent"

        onVisibleChanged: {
            if (visible) {
                wallpaperRoot.rescanWallpapers()
            }
        }

        Rectangle {
            anchors.fill: parent
            radius: 12
            color: Colors.bg()
            border.color: Colors.c(1)
            border.width: 2

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 20
                spacing: 14

                RowLayout {
                    Layout.fillWidth: true

                    Text {
                        text: "Wallpaper Picker"
                        color: Colors.c(7)
                        font.pixelSize: 18
                        font.bold: true
                        font.family: "Hack Nerd Font"
                    }

                    Item { Layout.fillWidth: true }

                    Rectangle {
                        implicitWidth: randomRow.implicitWidth + 20
                        implicitHeight: 30
                        radius: 8
                        color: Colors.c(1)

                        RowLayout {
                            id: randomRow
                            anchors.centerIn: parent
                            spacing: 6

                            Text {
                                text: "\uF021"
                                color: Colors.c(0)
                                font.pixelSize: 14
                                font.family: "Hack Nerd Font"
                            }
                            Text {
                                text: "Random"
                                color: Colors.c(0)
                                font.pixelSize: 13
                                font.bold: true
                                font.family: "Hack Nerd Font"
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: wallpaperRoot.setRandomWallpaper()
                        }
                    }
                }

                Text {
                    visible: wallpaperRoot.wallpaperList.length === 0
                    text: "No images found in your Wallpapers folder"
                    color: Colors.c(8)
                    font.pixelSize: 13
                    font.family: "Hack Nerd Font"
                    Layout.alignment: Qt.AlignCenter
                }

                GridView {
                    id: grid
                    visible: wallpaperRoot.wallpaperList.length > 0
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    property int columns: Math.max(3, Math.floor(width / 240))
                    cellWidth: width / columns
                    cellHeight: cellWidth * 0.65

                    model: wallpaperRoot.wallpaperList
                    delegate: Item {
                        width: grid.cellWidth
                        height: grid.cellHeight

                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: 6
                            radius: 8
                            color: Colors.c(0)
                            border.color: wallpaperRoot.currentWallpaper === modelData ? Colors.c(1) : Colors.c(8)
                            border.width: wallpaperRoot.currentWallpaper === modelData ? 3 : 1
                            clip: true

                            Image {
                                anchors.fill: parent
                                anchors.margins: 3
                                source: "file://" + modelData
                                cache: false
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: wallpaperRoot.applyWallpaper(modelData)
                            }
                        }
                    }
                }
            }
        }
    }
}
