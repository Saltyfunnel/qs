import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import QtQuick
import QtQuick.Layouts

// reusable pill look, matches the waybar CSS module pills
component Pill: Rectangle {
    default property alias content: inner.data
    radius: 16
    border.width: 3
    border.color: Colors.c(1)
    color: Colors.background
    implicitHeight: 30
    implicitWidth: inner.implicitWidth + 24
    Row {
        id: inner
        anchors.centerIn: parent
        spacing: 6
    }
}

PanelWindow {
    id: bar

    // set from shell.qml
    property var controlCenter

    anchors.top: true
    anchors.left: true
    anchors.right: true
    implicitHeight: 40
    color: "transparent"

    // ---------------- clock ----------------
    property var now: new Date()
    Timer { interval: 1000; running: true; repeat: true; onTriggered: bar.now = new Date() }

    // ---------------- updates ----------------
    property int updateCount: 0
    Process {
        id: updatesProc
        command: ["bash", "-c", "count=$(checkupdates 2>/dev/null | wc -l); aur=$(yay -Qua 2>/dev/null | wc -l); echo $((count + aur))"]
        stdout: StdioCollector { onStreamFinished: bar.updateCount = parseInt(text.trim()) || 0 }
    }
    Timer { interval: 3600000; running: true; repeat: true; triggeredOnStart: true; onTriggered: updatesProc.running = true }

    // ---------------- firefox / steam presence ----------------
    property bool firefoxRunning: false
    property bool steamRunning: false
    Process {
        id: presenceProc
        command: ["bash", "-c", "pgrep -x firefox >/dev/null && echo f; pgrep -x steam >/dev/null && echo s"]
        stdout: StdioCollector {
            onStreamFinished: {
                bar.firefoxRunning = text.includes("f")
                bar.steamRunning = text.includes("s")
            }
        }
    }
    Timer { interval: 5000; running: true; repeat: true; triggeredOnStart: true; onTriggered: presenceProc.running = true }

    // ---------------- media ----------------
    property var activePlayer: Mpris.players.values.length > 0 ? Mpris.players.values[0] : null

    // ---------------- audio / battery ----------------
    property var sink: Pipewire.defaultAudioSink
    PwObjectTracker { objects: [bar.sink] }
    property var battery: UPower.displayDevice

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 6
        anchors.rightMargin: 6
        anchors.topMargin: 4
        anchors.bottomMargin: 4
        spacing: 6

        // ---- workspaces pill ----
        Pill {
            Row {
                spacing: 4
                Repeater {
                    model: Hyprland.workspaces
                    delegate: Text {
                        property var ws: modelData
                        text: ws.name
                        color: Hyprland.focusedWorkspace && Hyprland.focusedWorkspace.id === ws.id ? Colors.c(1) : Colors.foreground
                        font.pixelSize: 13
                        font.bold: true
                        MouseArea { anchors.fill: parent; onClicked: Hyprland.dispatch("workspace " + ws.id) }
                    }
                }
            }
        }

        // ---- active window pill ----
        Pill {
            visible: Hyprland.activeToplevel !== null
            Text {
                text: Hyprland.activeToplevel ? "󰣇 " + Hyprland.activeToplevel.title : ""
                color: Colors.c(4)
                font.pixelSize: 12
                elide: Text.ElideRight
                width: Math.min(implicitWidth, 380)
            }
        }

        Item { Layout.fillWidth: true }

        // ---- clock pill ----
        Pill {
            Text {
                text: Qt.formatDateTime(bar.now, "HH:mm")
                color: Colors.c(1)
                font.pixelSize: 13
                font.bold: true
            }
        }

        Item { Layout.fillWidth: true }

        // ---- updates pill ----
        Pill {
            visible: bar.updateCount > 0
            Text { text: "󰚰 " + bar.updateCount; color: Colors.c(4) }
            MouseArea { anchors.fill: parent; onClicked: Quickshell.execDetached(["kitty", "--", "yay"]) }
        }

        // ---- media pill ----
        Pill {
            visible: bar.activePlayer !== null
            Text {
                text: bar.activePlayer ? "󰓇 " + (bar.activePlayer.trackArtist || "") + " - " + (bar.activePlayer.trackTitle || "") : ""
                color: Colors.c(10)
                elide: Text.ElideRight
                width: Math.min(implicitWidth, 260)
            }
        }

        // ---- firefox pill ----
        Pill {
            visible: bar.firefoxRunning
            Text { text: "󰈹"; color: Colors.c(9) }
        }

        // ---- steam pill ----
        Pill {
            visible: bar.steamRunning
            Text { text: "󰓓"; color: Colors.c(13) }
        }

        // ---- hardware pill: status glance + control center toggle ----
        Pill {
            Row {
                spacing: 10
                Text {
                    text: (bar.sink && bar.sink.audio && bar.sink.audio.muted) ? "󰝟" : "󰕾 " + Math.round((bar.sink && bar.sink.audio ? bar.sink.audio.volume : 0) * 100) + "%"
                    color: Colors.c(8)
                }
                Text {
                    visible: bar.battery !== null && bar.battery.isLaptopBattery
                    text: "󰁹 " + Math.round((bar.battery ? bar.battery.percentage : 0) * 100) + "%"
                    color: Colors.c(9)
                }
                Text {
                    text: "󰢻"
                    color: Colors.c(1)
                    font.bold: true
                    MouseArea { anchors.fill: parent; onClicked: if (bar.controlCenter) bar.controlCenter.toggle() }
                }
            }
        }
    }
}
