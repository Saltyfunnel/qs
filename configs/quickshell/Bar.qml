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

            Pill { AppLauncher {} }

            Workspaces {}

            // Left padding spacer to center-isolate the clock
            Item { Layout.preferredWidth: 12 }

            Clock {}

            // Right padding spacer to center-isolate the clock
            Item { Layout.preferredWidth: 12 }

            Pill { ControlCentre {} }

            Pill { visible: trayContent.implicitWidth > 0; Tray { id: trayContent } }

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
