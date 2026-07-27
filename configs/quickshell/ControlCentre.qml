import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire
import Quickshell.Bluetooth
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

PanelWindow {
    id: cc

    property bool open: false
    function toggle() { open = !open }

    visible: open
    anchors.top: true
    anchors.right: true
    margins.top: 38
    margins.right: 8
    implicitWidth: 340
    implicitHeight: content.implicitHeight + 24
    color: "transparent"
    exclusiveZone: 0

    Rectangle {
        anchors.fill: parent
        radius: 16
        color: Colors.background
        border.width: 3
        border.color: Colors.c(1)
    }

    // ---------------- audio ----------------
    property var sink: Pipewire.defaultAudioSink
    property var source: Pipewire.defaultAudioSource
    PwObjectTracker { objects: [cc.sink, cc.source] }

    // ---------------- media ----------------
    property var player: Mpris.players.values.length > 0 ? Mpris.players.values[0] : null

    // ---------------- wifi (nmcli) ----------------
    property bool wifiEnabled: true
    property string wifiSsid: ""
    Process {
        id: wifiStatus
        command: ["bash", "-c", "nmcli -t -f WIFI g; nmcli -t -f active,ssid dev wifi | grep '^yes' | cut -d: -f2"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split("\n")
                cc.wifiEnabled = lines[0] === "enabled"
                cc.wifiSsid = lines.length > 1 ? lines[1] : ""
            }
        }
    }
    function refreshWifi() { wifiStatus.running = true }
    function toggleWifi() {
        Quickshell.execDetached(["nmcli", "radio", "wifi", cc.wifiEnabled ? "off" : "on"])
        refreshTimer.restart()
    }

    // ---------------- bluetooth ----------------
    property var btAdapter: Bluetooth.defaultAdapter

    // ---------------- brightness ----------------
    property real brightness: 0.5
    Process {
        id: brightnessStatus
        command: ["bash", "-c", "brightnessctl get; brightnessctl max"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split("\n")
                if (lines.length >= 2) cc.brightness = parseFloat(lines[0]) / parseFloat(lines[1])
            }
        }
    }
    function setBrightness(v) {
        Quickshell.execDetached(["brightnessctl", "set", Math.round(v * 100) + "%"])
    }

    Timer {
        id: refreshTimer
        interval: 800
        onTriggered: { wifiStatus.running = true; brightnessStatus.running = true }
    }
    Component.onCompleted: { wifiStatus.running = true; brightnessStatus.running = true }

    ColumnLayout {
        id: content
        anchors.fill: parent
        anchors.margins: 12
        spacing: 14

        // ---- media ----
        ColumnLayout {
            visible: cc.player !== null
            spacing: 4
            Text {
                text: cc.player ? (cc.player.trackTitle || "Unknown title") : ""
                color: Colors.foreground
                font.bold: true
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
            Text {
                text: cc.player ? (cc.player.trackArtist || "") : ""
                color: Colors.c(8)
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
            RowLayout {
                spacing: 16
                Layout.alignment: Qt.AlignHCenter
                Text { text: "󰒮"; color: Colors.foreground; MouseArea { anchors.fill: parent; onClicked: cc.player && cc.player.previous() } }
                Text {
                    text: cc.player && cc.player.isPlaying ? "󰏤" : "󰐊"
                    color: Colors.foreground
                    font.pixelSize: 18
                    MouseArea { anchors.fill: parent; onClicked: if (cc.player) cc.player.isPlaying = !cc.player.isPlaying }
                }
                Text { text: "󰒭"; color: Colors.foreground; MouseArea { anchors.fill: parent; onClicked: cc.player && cc.player.next() } }
            }
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: Colors.c(8); visible: cc.player !== null }

        // ---- volume ----
        ColumnLayout {
            spacing: 4
            RowLayout {
                Text {
                    text: (cc.sink && cc.sink.audio && cc.sink.audio.muted) ? "󰝟" : "󰕾"
                    color: Colors.foreground
                    MouseArea {
                        anchors.fill: parent
                        onClicked: if (cc.sink && cc.sink.audio) cc.sink.audio.muted = !cc.sink.audio.muted
                    }
                }
                Text { text: "Volume"; color: Colors.foreground; Layout.fillWidth: true }
                Text { text: Math.round((cc.sink && cc.sink.audio ? cc.sink.audio.volume : 0) * 100) + "%"; color: Colors.c(8) }
            }
            Slider {
                Layout.fillWidth: true
                from: 0; to: 1
                value: cc.sink && cc.sink.audio ? cc.sink.audio.volume : 0
                onMoved: if (cc.sink && cc.sink.audio) { cc.sink.audio.muted = false; cc.sink.audio.volume = value }
            }
        }

        ColumnLayout {
            spacing: 4
            RowLayout {
                Text { text: "󰍬"; color: Colors.foreground }
                Text { text: "Microphone"; color: Colors.foreground; Layout.fillWidth: true }
                Text { text: Math.round((cc.source && cc.source.audio ? cc.source.audio.volume : 0) * 100) + "%"; color: Colors.c(8) }
            }
            Slider {
                Layout.fillWidth: true
                from: 0; to: 1
                value: cc.source && cc.source.audio ? cc.source.audio.volume : 0
                onMoved: if (cc.source && cc.source.audio) { cc.source.audio.muted = false; cc.source.audio.volume = value }
            }
        }

        // ---- brightness ----
        ColumnLayout {
            spacing: 4
            RowLayout {
                Text { text: "󰃟"; color: Colors.foreground }
                Text { text: "Brightness"; color: Colors.foreground; Layout.fillWidth: true }
                Text { text: Math.round(cc.brightness * 100) + "%"; color: Colors.c(8) }
            }
            Slider {
                Layout.fillWidth: true
                from: 0; to: 1
                value: cc.brightness
                onMoved: cc.setBrightness(value)
            }
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: Colors.c(8) }

        // ---- wifi ----
        RowLayout {
            spacing: 8
            Text { text: cc.wifiEnabled ? "󰤨" : "󰤭"; color: Colors.foreground }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                Text { text: "Wi-Fi"; color: Colors.foreground }
                Text { text: cc.wifiEnabled ? (cc.wifiSsid || "Not connected") : "Off"; color: Colors.c(8); font.pixelSize: 11 }
            }
            Switch { checked: cc.wifiEnabled; onToggled: cc.toggleWifi() }
        }
        Text {
            text: "Open network manager"
            color: Colors.c(1)
            font.pixelSize: 11
            MouseArea { anchors.fill: parent; onClicked: Quickshell.execDetached(["kitty", "-e", "nmtui"]) }
        }

        // ---- bluetooth ----
        RowLayout {
            spacing: 8
            Text { text: "󰂯"; color: Colors.foreground }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                Text { text: "Bluetooth"; color: Colors.foreground }
                Text {
                    text: cc.btAdapter && cc.btAdapter.devices.values.length > 0
                        ? cc.btAdapter.devices.values.filter(d => d.connected).map(d => d.name).join(", ") || "No device connected"
                        : "No device connected"
                    color: Colors.c(8)
                    font.pixelSize: 11
                    elide: Text.ElideRight
                }
            }
            Switch {
                checked: cc.btAdapter ? cc.btAdapter.enabled : false
                onToggled: if (cc.btAdapter) cc.btAdapter.enabled = checked
            }
        }
        Text {
            text: "Open Bluetooth manager"
            color: Colors.c(1)
            font.pixelSize: 11
            MouseArea { anchors.fill: parent; onClicked: Quickshell.execDetached(["blueman-manager"]) }
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: Colors.c(8) }

        // ---- power ----
        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 24
            Text { text: "⏻"; color: Colors.c(9); font.pixelSize: 18; MouseArea { anchors.fill: parent; onClicked: Quickshell.execDetached(["systemctl", "poweroff"]) } }
            Text { text: "󰜉"; color: Colors.foreground; font.pixelSize: 18; MouseArea { anchors.fill: parent; onClicked: Quickshell.execDetached(["systemctl", "reboot"]) } }
            Text { text: "󰍃"; color: Colors.foreground; font.pixelSize: 18; MouseArea { anchors.fill: parent; onClicked: Hyprland.dispatch("exit") } }
        }
    }
}
