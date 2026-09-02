import Quickshell.Services.SystemTray
import QtQuick

Row {
    spacing: 8
    Repeater {
        model: SystemTray.items
        delegate: Image {
            source: modelData.icon
            width: 16; height: 16
            MouseArea { anchors.fill: parent; onClicked: modelData.activate() }
        }
    }
}
