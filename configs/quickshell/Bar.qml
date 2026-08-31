import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Services.Pipewire
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

    property var sink: Pipewire.defaultAudioSink
    PwObjectTracker { objects: [bar.sink] }

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

        // Smoothly animate total bar width when children expand
        Behavior on implicitWidth {
            NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
        }

        RowLayout {
            id: content
            anchors.centerIn: parent
            spacing: 6

            Workspaces {}

            Pill { visible: mediaContent.implicitWidth > 0; Media { id: mediaContent } }
            Clock {}

            // Example Slide-out Drawer for Utility Apps/Actions
            Pill {
                id: drawerPill
                property bool expanded: false

                // Track total width based on expanded state
                implicitWidth: drawerRow.implicitWidth + 12

                Behavior on implicitWidth {
                    NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
                }

                RowLayout {
                    id: drawerRow
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 4

                    // Toggle button to trigger slide-out
                    Text {
                        text: drawerPill.expanded ? "󰅃" : "󰅀" // Replace with preferred icon/symbol
                        color: Colors.fg()
                        font.pixelSize: 14

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: drawerPill.expanded = !drawerPill.expanded
                        }
                    }

                    // Collapsible sliding container
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
                            Wallpaper {}
                            Screenshot {}
                        }
                    }
                }
            }

            Pill { visible: updateContent.implicitWidth > 0; Update { id: updateContent } }
            Pill { Monitor {} }
            Pill { visible: netContent.implicitWidth > 0; Network { id: netContent } }
            Pill { visible: btContent.implicitWidth > 0; Bluetooth { id: btContent } }
            Pill { Audio { sink: bar.sink } }
            Pill { visible: powerContent.visible; Power { id: powerContent } }
            Pill { visible: trayContent.implicitWidth > 0; Tray { id: trayContent } }
            Pill { SystemInfo {} }
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
