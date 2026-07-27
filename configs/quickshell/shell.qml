import Quickshell
import QtQuick

ShellRoot {
    ControlCenter {
        id: controlCenter
    }

    Bar {
        controlCenter: controlCenter
    }
}
