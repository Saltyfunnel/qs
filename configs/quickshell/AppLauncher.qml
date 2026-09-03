import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Effects

Item {
    id: appLauncherRoot

    implicitWidth: 28
    implicitHeight: 28

    property string searchQuery: ""
    property string hoveredShortcutLabel: ""
    property string currentWallpaperSource: ""

    // Helper script to read pywal's wallpaper directly and create a symlink with a valid extension
    Process {
        id: walPathReader
        command: ["bash", "-c", "
            WAL_FILE=\"$(cat ~/.cache/wal/wal 2>/dev/null || echo '')\"
            if [ -z \"$WAL_FILE\" ] || [ ! -f \"$WAL_FILE\" ]; then
                WAL_FILE=~/.cache/wal/wal
            fi

            if [ -f \"$WAL_FILE\" ]; then
                # Link to a path with a clear file extension so Qt can decode it
                EXT=\"${WAL_FILE##*.}\"
                [ \"$EXT\" = \"$WAL_FILE\" ] && EXT=\"png\"
                TARGET=\"/tmp/quickshell_bg.$EXT\"

                ln -sf \"$WAL_FILE\" \"$TARGET\"
                echo \"file://$TARGET\"
            fi
        "]
        running: false

        stdout: SplitParser {
            onRead: data => {
                let cleanUrl = data.trim()
                if (cleanUrl !== "" && cleanUrl.startsWith("file://")) {
                    // Update source with cache buster
                    appLauncherRoot.currentWallpaperSource = cleanUrl + "?t=" + Date.now()
                }
            }
        }
    }

    Component.onCompleted: {
        walPathReader.running = true
    }

    function launchCmd(cmd) {
        cmdRunner.command = ["bash", "-c", cmd]
        cmdRunner.running = false
        cmdRunner.running = true
        appPopup.visible = false
    }

    Process {
        id: cmdRunner
    }

    Text {
        anchors.centerIn: parent
        text: "\uF303 "
        color: iconMouse.containsMouse ? Colors.c(7) : Colors.c(0)
        font.pixelSize: 16
        font.bold: true
        font.family: "Hack Nerd Font, HackNerdFont, Symbols Nerd Font, monospace"
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter

        Behavior on color {
            ColorAnimation { duration: 150 }
        }
    }

    MouseArea {
        id: iconMouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            appLauncherRoot.searchQuery = ""
            appLauncherRoot.hoveredShortcutLabel = ""
            searchInput.text = ""

            // Re-read wallpaper in case pywal changed it
            walPathReader.running = false
            walPathReader.running = true

            bar.togglePopup(appPopup)
            if (appPopup.visible) {
                searchInput.forceActiveFocus()
            }
        }
    }

    PopupWindow {
        id: appPopup
        visible: false
        anchor.window: bar
        anchor.rect.x: (bar.width - appPopup.implicitWidth) / 2
        anchor.rect.y: (bar.screen.height - appPopup.implicitHeight) / 2

        grabFocus: true
        implicitWidth: 420
        implicitHeight: 540
        color: "transparent"

        Rectangle {
            anchors.fill: parent
            radius: 12
            color: "#1a1a1a" // Fallback dark background if wallpaper fails
            border.color: Colors.c(1)
            border.width: 2
            clip: true

            // Wallpaper Image Layer
            Image {
                id: bgWallpaper
                anchors.fill: parent
                source: appLauncherRoot.currentWallpaperSource
                fillMode: Image.PreserveAspectCrop
                asynchronous: false
                cache: false
                z: 0
            }

            // Dark Overlay
            Rectangle {
                anchors.fill: parent
                color: Qt.rgba(0, 0, 0, 0.65)
                z: 1
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 12
                z: 2

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 38
                    radius: 6
                    color: Qt.rgba(0, 0, 0, 0.35)
                    border.color: searchInput.activeFocus ? Colors.c(1) : Qt.tint(Colors.c(8), Qt.rgba(0, 0, 0, 0.3))
                    border.width: 1

                    TextField {
                        id: searchInput
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        placeholderText: "Search..."
                        placeholderTextColor: Colors.c(8)
                        color: Colors.c(7)
                        font.pixelSize: 13
                        font.family: "Hack Nerd Font, HackNerdFont, monospace"
                        background: null
                        onTextChanged: appLauncherRoot.searchQuery = text

                        Keys.onEscapePressed: appPopup.visible = false
                        Keys.onReturnPressed: {
                            if (appList.count > 0) {
                                var firstItem = appList.itemAtIndex(0)
                                if (firstItem && firstItem.appData) {
                                    firstItem.appData.execute()
                                    appPopup.visible = false
                                }
                            }
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    Repeater {
                        model: [
                            { label: "Files", icon: "\uF350", cmd: "thunar" },
                            { label: "Terminal", icon: "\uF013", cmd: "kitty" },
                            { label: "Browser", icon: "\uF0AC", cmd: "firefox" },
                            { label: "Editor", icon: "\uF121", cmd: "zeditor" }
                        ]

                        delegate: Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 36
                            radius: 6
                            color: shortcutMouse.containsMouse ? Colors.c(1) : Qt.rgba(0, 0, 0, 0.25)
                            border.color: Colors.c(1)
                            border.width: 1

                            Text {
                                anchors.centerIn: parent
                                text: modelData.icon
                                color: shortcutMouse.containsMouse ? Colors.background : Colors.c(7)
                                font.pixelSize: 15
                                font.family: "Hack Nerd Font, HackNerdFont, monospace"
                            }

                            MouseArea {
                                id: shortcutMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onEntered: appLauncherRoot.hoveredShortcutLabel = modelData.label
                                onExited: appLauncherRoot.hoveredShortcutLabel = ""
                                onClicked: appLauncherRoot.launchCmd(modelData.cmd)
                            }
                        }
                    }
                }

                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 16

                    Text {
                        anchors.centerIn: parent
                        text: appLauncherRoot.hoveredShortcutLabel
                        color: Colors.c(1)
                        font.pixelSize: 11
                        font.bold: true
                        font.family: "Hack Nerd Font, HackNerdFont, monospace"
                        visible: appLauncherRoot.hoveredShortcutLabel !== ""
                    }
                }

                ListView {
                    id: appList
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 4
                    clip: true

                    model: DesktopEntries.applications ? DesktopEntries.applications.values : []

                    delegate: Rectangle {
                        id: appItem
                        property var appData: modelData

                        visible: {
                            if (!modelData) return false
                            var name = (modelData.name || "").toLowerCase()
                            var query = appLauncherRoot.searchQuery.toLowerCase()

                            var matchesQuery = query === "" || name.indexOf(query) !== -1
                            var notExcluded = !name.includes("helper") &&
                                              !name.includes("daemon") &&
                                              !name.includes("avahi") &&
                                              !name.includes("session")

                            return matchesQuery && notExcluded
                        }

                        height: visible ? 46 : 0
                        width: appList.width
                        radius: 6
                        color: itemMouse.containsMouse ? Qt.tint(Colors.c(1), Qt.rgba(0, 0, 0, 0.3)) : Qt.rgba(0, 0, 0, 0.2)
                        border.color: itemMouse.containsMouse ? Colors.c(1) : "transparent"
                        border.width: 1

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            spacing: 10

                            Item {
                                Layout.preferredWidth: 22
                                Layout.preferredHeight: 22

                                Image {
                                    id: rawAppIcon
                                    anchors.fill: parent
                                    fillMode: Image.PreserveAspectFit
                                    visible: false

                                    function resolveIcon(iconName) {
                                        if (!iconName) return "image://icon/application-x-executable"
                                        if (iconName.startsWith("/") || iconName.startsWith("file://")) return iconName
                                        if (iconName.startsWith("image://")) return iconName
                                        return "image://icon/" + iconName
                                    }

                                    source: resolveIcon(modelData ? modelData.icon : "")

                                    onStatusChanged: {
                                        if (status === Image.Error && source !== "image://icon/application-x-executable") {
                                            source = "image://icon/application-x-executable"
                                        }
                                    }
                                }

                                MultiEffect {
                                    anchors.fill: rawAppIcon
                                    source: rawAppIcon
                                    colorization: 1.0
                                    colorizationColor: itemMouse.containsMouse ? Colors.c(7) : Colors.c(1)
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 0

                                Text {
                                    text: modelData ? modelData.name : ""
                                    color: Colors.c(7)
                                    font.pixelSize: 12
                                    font.bold: true
                                    font.family: "Hack Nerd Font, HackNerdFont, monospace"
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }

                                Text {
                                    text: modelData ? (modelData.comment || modelData.genericName || "") : ""
                                    color: Colors.c(8)
                                    font.pixelSize: 10
                                    font.family: "Hack Nerd Font, HackNerdFont, monospace"
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                            }
                        }

                        MouseArea {
                            id: itemMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (modelData) {
                                    modelData.execute()
                                    appPopup.visible = false
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
