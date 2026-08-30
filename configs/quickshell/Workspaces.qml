import Quickshell
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts

RowLayout {
    id: wsRoot
    spacing: 6

    Repeater {
        model: 3
        delegate: Rectangle {
            id: wsBtn
            required property int index
            property int wsId: index + 1
            property bool isFocused: Hyprland.focusedWorkspace && Hyprland.focusedWorkspace.id === wsId

            implicitWidth: 28
            implicitHeight: 28
            Layout.preferredWidth: 28
            Layout.preferredHeight: 28

            // Circle geometry active only when focused
            radius: 14
            color: isFocused ? Colors.c(1) : "transparent"
            border.color: isFocused ? Colors.c(1) : "transparent"
            border.width: isFocused ? 2 : 0

            Behavior on color {
                ColorAnimation { duration: 150 }
            }

            Text {
                anchors.centerIn: parent
                text: wsBtn.wsId
                color: wsBtn.isFocused ? Colors.background : Colors.c(8)
                font.pixelSize: 12
                font.bold: true
                font.family: "Monospace"
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                acceptedButtons: Qt.LeftButton
                onClicked: Hyprland.dispatch("hl.dsp.focus({ workspace = " + wsBtn.wsId + " })")
            }
        }
    }
}
