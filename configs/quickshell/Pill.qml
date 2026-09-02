import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root
    default property alias content: innerContent.data
    implicitWidth: innerContent.implicitWidth + 14
    implicitHeight: 24
    Layout.preferredWidth: implicitWidth
    Layout.preferredHeight: implicitHeight
    color: Colors.c(1)
    radius: 13
    RowLayout {
        id: innerContent
        anchors.centerIn: parent
        spacing: 6
    }
}
