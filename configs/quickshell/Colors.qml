pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick
Singleton {
    id: root
    readonly property string background: adapter.special.background
    readonly property string foreground: adapter.special.foreground
    readonly property string cursor: adapter.special.cursor
    // c(1) == {color1} etc, matches your waybar CSS variables
    function c(i) {
        return adapter.colors["color" + i] || root.foreground
    }
    function bg(alpha) {
        return Qt.rgba(
            parseInt(root.background.substr(1,2), 16) / 255,
            parseInt(root.background.substr(3,2), 16) / 255,
            parseInt(root.background.substr(5,2), 16) / 255,
            alpha !== undefined ? alpha : 0.92
        )
    }
    FileView {
        path: Quickshell.env("HOME") + "/.cache/wal/colors.json"
        watchChanges: true
        onFileChanged: reload()
        JsonAdapter {
            id: adapter
            property JsonObject special: JsonObject {
                property string background: "#1e1e2e"
                property string foreground: "#cdd6f4"
                property string cursor: "#cdd6f4"
            }
            property JsonObject colors: JsonObject {
                property string color0: "#1e1e2e"
                property string color1: "#f38ba8"
                property string color2: "#a6e3a1"
                property string color3: "#f9e2af"
                property string color4: "#89b4fa"
                property string color5: "#cba6f7"
                property string color6: "#94e2d5"
                property string color7: "#cdd6f4"
                property string color8: "#585b70"
                property string color9: "#f38ba8"
                property string color10: "#a6e3a1"
                property string color11: "#f9e2af"
                property string color12: "#89b4fa"
                property string color13: "#cba6f7"
                property string color14: "#94e2d5"
                property string color15: "#a6adc8"
            }
        }
    }
}
