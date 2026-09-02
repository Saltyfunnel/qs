import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts

PanelWindow {
    id: bar
    anchors.top: true
    implicitHeight: 40
    margins.top: 6
    color: "transparent"
    exclusionMode: ExclusionMode.Auto

    property var activePopup: null
    function togglePopup(popup) {
        if (activePopup && activePopup !== popup) {
            activePopup.visible = false
        }
        popup.visible = !popup.visible
        activePopup = popup.visible ? popup : null
    }
    function closeActivePopup() {
        if (activePopup) {
            activePopup.visible = false
            activePopup = null
        }
    }

    implicitWidth: megaPill.implicitWidth + 16

    Rectangle {
        id: megaPill
        anchors.centerIn: parent
        implicitWidth: content.implicitWidth + 20
        implicitHeight: 34
        radius: 17
        color: Colors.bg()
        border.color: Colors.c(1)
        border.width: 2

        Behavior on implicitWidth {
            NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
        }

        RowLayout {
            id: content
            anchors.centerIn: parent
            spacing: 6

            Workspaces {}
             Pill { visible: trayContent.implicitWidth > 0; Tray { id: trayContent } }

            Clock {}

            // App launcher — Wallpaper and Screenshot moved into ControlCentre, so this
            // is now a single-item drawer. Simplify to a plain Pill if you'd rather
            // drop the slide-out entirely.
            Pill {
                id: drawerPill
                property bool expanded: false

                implicitWidth: drawerRow.implicitWidth + 12

                Behavior on implicitWidth {
                    NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
                }

                RowLayout {
                    id: drawerRow
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 4

                    Text {
                        text: drawerPill.expanded ? "󰅃" : "󰅀"
                        color: Colors.fg()
                        font.pixelSize: 14

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: drawerPill.expanded = !drawerPill.expanded
                        }
                    }

                    Item {
                        id: slideOutContainer
                        implicitHeight: drawerItems.implicitHeight
                        implicitWidth: drawerPill.expanded ? drawerItems.implicitWidth : 0
                        clip: true

                        Behavior on implicitWidth {
                            NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
                        }

                        RowLayout {
                            id: drawerItems
                            spacing: 6

                            AppLauncher {}
                        }
                    }
                }
            }

            Pill { ControlCentre {} }
            Pill { Session {} }
        }
    }

    PanelWindow {
        id: dismissOverlay
        anchors.top: true
        anchors.bottom: true
        anchors.left: true
        anchors.right: true
        color: "transparent"
        visible: bar.activePopup !== null
        exclusionMode: ExclusionMode.Ignore
        MouseArea {
            anchors.fill: parent
            onClicked: bar.closeActivePopup()
        }
    }
}
