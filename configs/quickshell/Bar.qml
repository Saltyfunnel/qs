import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Services.Pipewire
import QtQuick
import QtQuick.Layouts

PanelWindow {
    id: bar
    anchors.top: true
    anchors.left: true
    anchors.right: true
    implicitHeight: 38
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

    Item {
        id: barContent
        anchors.fill: parent

        // ---- LEFT MODULES ----
        RowLayout {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: 4
            spacing: 4
            AppLauncher {}
            Workspaces {}
            Pill { visible: trayContent.implicitWidth > 0; Tray { id: trayContent } }
            Pill {
                visible: mediaContent.implicitWidth > 0
                Media { id: mediaContent }
            }
        }

        // ---- CENTER MODULE ----
        Clock {
            anchors.centerIn: parent
        }

        // ---- RIGHT MODULES ----
        RowLayout {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.rightMargin: 4
            spacing: 4
             Pill { visible: updateContent.implicitWidth > 0; Update { id: updateContent } }
            Pill { Screenshot {} }
            Pill { Wallpaper {} }
            Pill { SystemInfo {} }
            Pill { visible: monitorContent.implicitWidth > 0; Monitor { id: monitorContent } }
            Pill { visible: netContent.implicitWidth > 0; Network { id: netContent } }
            Pill { visible: btContent.implicitWidth > 0; Bluetooth { id: btContent } }
            Pill { Audio { sink: bar.sink } }
            Pill { visible: powerContent.visible; Power { id: powerContent } }
            Pill { Session {} }
        }
    }

    // Full-screen transparent overlay to capture outside clicks
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
