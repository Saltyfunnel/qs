import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

Item {
    id: networkRoot

    property string connectionType: "none"
    property string activeDevice: ""
    property string activeName: "Disconnected"
    property string subStatus: "No Connection"
    property string ipAddress: "--"
    property string gateway: "--"
    property string pingMs: "--"
    property string packetLoss: "0%"
    property string rxRate: "0 B/s"
    property string txRate: "0 B/s"
    property string totalDownloaded: "0 MB"
    property string totalUploaded: "0 MB"
    property string wifiBand: "5GHz"
    property bool bandAutomatic: true
    property bool wifiEnabled: true
    property string selectedDns: "DHCP"

    property var knownNetworks: []
    property var otherNetworks: []

    // Internal counters for network speed computation
    property real lastRxBytes: 0
    property real lastTxBytes: 0
    property real lastSpeedCheckTime: 0

    implicitWidth: 28
    implicitHeight: 28

    Process {
        id: statusFetcher
        command: ["sh", "-c", "
            TYPE=$(nmcli -t -f TYPE,DEVICE,STATE dev | grep ':connected' | head -n1)
            if [ -n \"$TYPE\" ]; then
                DEV_TYPE=$(echo \"$TYPE\" | cut -d: -f1)
                DEV_NAME=$(echo \"$TYPE\" | cut -d: -f2)

                IP=$(ip route get 1.1.1.1 2>/dev/null | grep -oP 'src \\K\\S+')
                GW=$(ip route get 1.1.1.1 2>/dev/null | grep -oP 'via \\K\\S+')

                if [ \"$DEV_TYPE\" = \"ethernet\" ]; then
                    SPEED=$(cat /sys/class/net/$DEV_NAME/speed 2>/dev/null)
                    if [ -n \"$SPEED\" ]; then SPEED=\"${SPEED} Mb/s\"; else SPEED=\"Wired Link\"; fi
                    echo \"TYPE:ethernet|DEV:$DEV_NAME|NAME:Wired Connection|SUB:$SPEED|IP:${IP:---}|GW:${GW:---}\"
                elif [ \"$DEV_TYPE\" = \"wifi\" ]; then
                    WIFI_INFO=$(nmcli -t -f active,ssid,signal,freq dev wifi | grep '^yes:' | head -n1)
                    SSID=$(echo \"$WIFI_INFO\" | cut -d: -f2)
                    SIG=$(echo \"$WIFI_INFO\" | cut -d: -f3)
                    FREQ=$(echo \"$WIFI_INFO\" | cut -d: -f4 | grep -oP '^[0-9]+')
                    BAND=\"2.4GHz\"
                    if [ -n \"$FREQ\" ] && [ \"$FREQ\" -gt 4000 ]; then BAND=\"5GHz\"; fi
                    echo \"TYPE:wifi|DEV:$DEV_NAME|NAME:${SSID:-Wi-Fi}|SUB:HAULING BYTES|IP:${IP:---}|GW:${GW:---}|BAND:$BAND\"
                fi
            else
                echo \"TYPE:none|DEV:|NAME:Disconnected|SUB:No Active Network|IP:--|GW:--|BAND:N/A\"
            fi
        "]
        running: true

        stdout: SplitParser {
            onRead: data => {
                var line = data.trim()
                if (!line) return

                var parts = line.split("|")
                var kv = {}
                for (var i = 0; i < parts.length; i++) {
                    var pair = parts[i].split(":")
                    if (pair.length >= 2) {
                        kv[pair[0]] = pair.slice(1).join(":")
                    }
                }

                if (kv["TYPE"]) networkRoot.connectionType = kv["TYPE"]
                if (kv["DEV"]) networkRoot.activeDevice = kv["DEV"]
                if (kv["NAME"]) networkRoot.activeName = kv["NAME"]
                if (kv["SUB"]) networkRoot.subStatus = kv["SUB"]
                if (kv["IP"]) networkRoot.ipAddress = kv["IP"]
                if (kv["GW"]) networkRoot.gateway = kv["GW"]
                if (kv["BAND"]) networkRoot.wifiBand = kv["BAND"]
            }
        }
    }

    Process {
        id: pingFetcher
        command: ["sh", "-c", "ping -c 3 -W 1 1.1.1.1 2>/dev/null | awk '/packet loss/ {print $6} /rtt/ {print $4}'"]
        running: true
        stdout: SplitParser {
            onRead: data => {
                var lines = data.trim().split("\n")
                if (lines.length >= 1 && lines[0].includes("%")) {
                    networkRoot.packetLoss = lines[0]
                }
                if (lines.length >= 2) {
                    var parts = lines[1].split("/")
                    if (parts.length >= 2) {
                        var val = parseFloat(parts[1])
                        networkRoot.pingMs = !isNaN(val) ? Math.round(val) + " ms" : "--"
                    }
                }
            }
        }
    }

    Process {
        id: trafficFetcher
        command: ["sh", "-c", "
            if [ -n \"" + networkRoot.activeDevice + "\" ]; then
                RX=$(cat /sys/class/net/" + networkRoot.activeDevice + "/statistics/rx_bytes 2>/dev/null || echo 0)
                TX=$(cat /sys/class/net/" + networkRoot.activeDevice + "/statistics/tx_bytes 2>/dev/null || echo 0)
                echo \"$RX $TX\"
            else
                echo \"0 0\"
            fi
        "]
        running: true
        stdout: SplitParser {
            onRead: data => {
                var parts = data.trim().split(/\s+/)
                if (parts.length >= 2) {
                    var rx = parseFloat(parts[0])
                    var tx = parseFloat(parts[1])
                    var currentTime = Date.now()

                    if (networkRoot.lastSpeedCheckTime > 0) {
                        var timeDiff = (currentTime - networkRoot.lastSpeedCheckTime) / 1000.0
                        if (timeDiff > 0) {
                            var rxSpeed = (rx - networkRoot.lastRxBytes) / timeDiff
                            var txSpeed = (tx - networkRoot.lastTxBytes) / timeDiff

                            networkRoot.rxRate = formatSpeed(rxSpeed)
                            networkRoot.txRate = formatSpeed(txSpeed)
                        }
                    }

                    networkRoot.lastRxBytes = rx
                    networkRoot.lastTxBytes = tx
                    networkRoot.lastSpeedCheckTime = currentTime

                    networkRoot.totalDownloaded = formatBytes(rx)
                    networkRoot.totalUploaded = formatBytes(tx)
                }
            }
        }
    }

    function formatSpeed(bytesPerSec) {
        if (bytesPerSec < 0) bytesPerSec = 0
        if (bytesPerSec >= 1024 * 1024 * 1024) return (bytesPerSec / (1024 * 1024 * 1024)).toFixed(1) + " GB/s"
        if (bytesPerSec >= 1024 * 1024) return (bytesPerSec / (1024 * 1024)).toFixed(1) + " MB/s"
        if (bytesPerSec >= 1024) return (bytesPerSec / 1024).toFixed(0) + " KB/s"
        return Math.round(bytesPerSec) + " B/s"
    }

    function formatBytes(bytes) {
        if (bytes >= 1024 * 1024 * 1024) return (bytes / (1024 * 1024 * 1024)).toFixed(1) + " GB"
        if (bytes >= 1024 * 1024) return (bytes / (1024 * 1024)).toFixed(1) + " MB"
        if (bytes >= 1024) return (bytes / 1024).toFixed(1) + " KB"
        return bytes + " B"
    }

    Process {
        id: nearbyFetcher
        command: ["sh", "-c", "nmcli -t -f active,ssid dev wifi list 2>/dev/null | grep -v '^$'"]
        running: networkRoot.wifiEnabled
        stdout: SplitParser {
            onRead: data => {
                var lines = data.trim().split("\n").filter(function(e) { return e.length > 0 })
                var known = []
                var other = []

                for (var i = 0; i < lines.length; i++) {
                    var parts = lines[i].split(":")
                    var isActive = parts[0] === "yes"
                    var ssid = parts.slice(1).join(":")

                    if (!ssid) continue

                    if (isActive) {
                        known.push({ ssid: ssid, connected: true })
                    } else {
                        if (other.indexOf(ssid) === -1 && !known.some(e => e.ssid === ssid)) {
                            other.push(ssid)
                        }
                    }
                }
                networkRoot.knownNetworks = known
                networkRoot.otherNetworks = other
            }
        }
    }

    Process {
        id: radioFetcher
        command: ["nmcli", "radio", "wifi"]
        running: true
        stdout: SplitParser {
            onRead: data => {
                networkRoot.wifiEnabled = (data.trim() === "enabled")
            }
        }
    }

    Process {
        id: dnsFetcher
        command: ["sh", "-c", "nmcli -t -f IP4.DNS dev show 2>/dev/null | head -n 1 | cut -d: -f2"]
        running: true
        stdout: SplitParser {
            onRead: data => {
                var dns = data.trim()
                if (dns === "1.1.1.1" || dns === "1.0.0.1") {
                    networkRoot.selectedDns = "Cloudflare"
                } else if (dns === "8.8.8.8" || dns === "8.8.4.4") {
                    networkRoot.selectedDns = "Google"
                } else if (dns !== "") {
                    networkRoot.selectedDns = "Custom"
                } else {
                    networkRoot.selectedDns = "DHCP"
                }
            }
        }
    }

    Timer {
        interval: 3000
        running: true
        repeat: true
        onTriggered: {
            statusFetcher.running = false
            statusFetcher.running = true
            pingFetcher.running = false
            pingFetcher.running = true
            trafficFetcher.running = false
            trafficFetcher.running = true
            radioFetcher.running = false
            radioFetcher.running = true
            dnsFetcher.running = false
            dnsFetcher.running = true
            if (networkRoot.wifiEnabled) {
                nearbyFetcher.running = false
                nearbyFetcher.running = true
            }
        }
    }

    Text {
        anchors.centerIn: parent
        text: networkRoot.connectionType === "ethernet" ? "󰈀" : (networkRoot.connectionType === "wifi" ? "󰤨" : "󰤮")
        color: Colors.c(0)
        font.pixelSize: 15
        font.family: "Hack Nerd Font"
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: bar.togglePopup(networkPopup)
    }

    PopupWindow {
        id: networkPopup
        visible: false
        anchor.item: networkRoot
        anchor.edges: Edges.Bottom | Edges.Left
        anchor.gravity: Edges.Bottom | Edges.Right
        anchor.margins.top: 8

        grabFocus: true

        implicitWidth: 340
        implicitHeight: mainLayout.implicitHeight + 24
        color: "transparent"

        Rectangle {
            anchors.fill: parent
            radius: 12
            color: Colors.bg()
            border.color: Colors.c(1)
            border.width: 1

            ColumnLayout {
                id: mainLayout
                anchors.fill: parent
                anchors.margins: 12
                spacing: 10

                // Header Block
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    Text {
                        text: networkRoot.connectionType === "ethernet" ? "󰈀" : (networkRoot.connectionType === "wifi" ? "󰤨" : "󰤮")
                        color: Colors.c(7)
                        font.pixelSize: 26
                        font.family: "Hack Nerd Font"
                    }

                    ColumnLayout {
                        spacing: 0
                        Text {
                            text: networkRoot.connectionType === "ethernet"
                                  ? ("Ethernet (" + networkRoot.activeDevice + ")")
                                  : networkRoot.activeName
                            color: Colors.c(7)
                            font.bold: true
                            font.pixelSize: 14
                            font.family: "Hack Nerd Font"
                        }
                        Text {
                            text: networkRoot.subStatus
                            color: Colors.c(8)
                            font.pixelSize: 9
                            font.bold: true
                            font.family: "Hack Nerd Font"
                        }
                    }

                    Item { Layout.fillWidth: true }

                    // QR Code Icon Button
                    Text {
                        text: "󰄀"
                        color: Colors.c(7)
                        font.pixelSize: 16
                        font.family: "Hack Nerd Font"
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                Quickshell.execDetached(["sh", "-c", "qrencode -t UTF8 \"WIFI:S:" + networkRoot.activeName + ";T:WPA;;\" | kitty -e sh -c 'cat; read -n1'"])
                            }
                        }
                    }

                    // Speedtest Icon Button
                    Text {
                        text: "󰓅"
                        color: Colors.c(7)
                        font.pixelSize: 16
                        font.family: "Hack Nerd Font"
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                Quickshell.execDetached(["sh", "-c", "kitty -e speedtest"])
                            }
                        }
                    }

                    // WiFi Master Switch Toggle
                    Rectangle {
                        implicitWidth: 36
                        implicitHeight: 18
                        radius: 9
                        color: networkRoot.wifiEnabled ? Colors.c(1) : Colors.c(0)
                        border.color: networkRoot.wifiEnabled ? Colors.c(1) : Colors.c(8)
                        border.width: 1

                        Rectangle {
                            x: networkRoot.wifiEnabled ? parent.width - width - 2 : 2
                            y: 2
                            width: 14
                            height: 14
                            radius: 7
                            color: networkRoot.wifiEnabled ? Colors.background : Colors.c(7)

                            Behavior on x {
                                NumberAnimation { duration: 150; easing.type: Easing.InOutQuad }
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                var cmd = networkRoot.wifiEnabled ? "nmcli radio wifi off" : "nmcli radio wifi on"
                                Quickshell.execDetached(["sh", "-c", cmd])
                                networkRoot.wifiEnabled = !networkRoot.wifiEnabled
                            }
                        }
                    }
                }

                // Stats Grid
                GridLayout {
                    Layout.fillWidth: true
                    columns: 2
                    rowSpacing: 4
                    columnSpacing: 12

                    Text { text: "Ping"; color: Colors.c(8); font.pixelSize: 10; font.family: "Hack Nerd Font" }
                    Text { text: networkRoot.pingMs; color: Colors.c(7); font.pixelSize: 10; font.bold: true; font.family: "Hack Nerd Font"; Layout.alignment: Qt.AlignRight }

                    Text { text: "Packet Loss"; color: Colors.c(8); font.pixelSize: 10; font.family: "Hack Nerd Font" }
                    Text { text: networkRoot.packetLoss; color: Colors.c(7); font.pixelSize: 10; font.bold: true; font.family: "Hack Nerd Font"; Layout.alignment: Qt.AlignRight }

                    Text { text: "Receiving"; color: Colors.c(8); font.pixelSize: 10; font.family: "Hack Nerd Font" }
                    Text { text: networkRoot.rxRate; color: Colors.c(7); font.pixelSize: 10; font.bold: true; font.family: "Hack Nerd Font"; Layout.alignment: Qt.AlignRight }

                    Text { text: "Sending"; color: Colors.c(8); font.pixelSize: 10; font.family: "Hack Nerd Font" }
                    Text { text: networkRoot.txRate; color: Colors.c(7); font.pixelSize: 10; font.bold: true; font.family: "Hack Nerd Font"; Layout.alignment: Qt.AlignRight }

                    Text { text: "Downloaded"; color: Colors.c(8); font.pixelSize: 10; font.family: "Hack Nerd Font" }
                    Text { text: networkRoot.totalDownloaded; color: Colors.c(7); font.pixelSize: 10; font.bold: true; font.family: "Hack Nerd Font"; Layout.alignment: Qt.AlignRight }

                    Text { text: "Uploaded"; color: Colors.c(8); font.pixelSize: 10; font.family: "Hack Nerd Font" }
                    Text { text: networkRoot.totalUploaded; color: Colors.c(7); font.pixelSize: 10; font.bold: true; font.family: "Hack Nerd Font"; Layout.alignment: Qt.AlignRight }

                    Text { text: "IP Address"; color: Colors.c(8); font.pixelSize: 10; font.family: "Hack Nerd Font" }
                    Text { text: networkRoot.ipAddress; color: Colors.c(7); font.pixelSize: 10; font.bold: true; font.family: "Hack Nerd Font"; Layout.alignment: Qt.AlignRight }

                    Text { text: "Gateway"; color: Colors.c(8); font.pixelSize: 10; font.family: "Hack Nerd Font" }
                    Text { text: networkRoot.gateway; color: Colors.c(7); font.pixelSize: 10; font.bold: true; font.family: "Hack Nerd Font"; Layout.alignment: Qt.AlignRight }
                }

                Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Colors.c(0) }

                // Wi-Fi Band Setting Section
                RowLayout {
                    Layout.fillWidth: true

                    Text {
                        text: "WI-FI BAND: " + networkRoot.wifiBand.toUpperCase()
                        color: Colors.c(8)
                        font.pixelSize: 9
                        font.bold: true
                        font.family: "Hack Nerd Font"
                    }

                    Item { Layout.fillWidth: true }

                    Text {
                        text: "AUTOMATIC"
                        color: Colors.c(8)
                        font.pixelSize: 9
                        font.bold: true
                        font.family: "Hack Nerd Font"
                    }

                    Rectangle {
                        implicitWidth: 28
                        implicitHeight: 14
                        radius: 7
                        color: networkRoot.bandAutomatic ? Colors.c(1) : Colors.c(0)

                        Rectangle {
                            x: networkRoot.bandAutomatic ? parent.width - width - 2 : 2
                            y: 2
                            width: 10
                            height: 10
                            radius: 5
                            color: Colors.c(7)

                            Behavior on x {
                                NumberAnimation { duration: 150; easing.type: Easing.InOutQuad }
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: networkRoot.bandAutomatic = !networkRoot.bandAutomatic
                        }
                    }
                }

                Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Colors.c(0) }

                // DNS Selection Section
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    Text {
                        text: "DNS PROVIDER"
                        color: Colors.c(8)
                        font.pixelSize: 9
                        font.bold: true
                        font.family: "Hack Nerd Font"
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 4

                        Repeater {
                            model: ["DHCP", "Cloudflare", "Google", "Custom"]

                            Rectangle {
                                Layout.fillWidth: true
                                implicitHeight: 32
                                radius: 4
                                color: networkRoot.selectedDns === modelData ? Colors.c(0) : "transparent"
                                border.color: networkRoot.selectedDns === modelData ? Colors.c(1) : Colors.c(8)
                                border.width: 1

                                Text {
                                    anchors.centerIn: parent
                                    text: modelData
                                    color: networkRoot.selectedDns === modelData ? Colors.c(7) : Colors.c(8)
                                    font.pixelSize: 10
                                    font.bold: true
                                    font.family: "Hack Nerd Font"
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        networkRoot.selectedDns = modelData
                                        var dnsCmd = ""
                                        if (modelData === "Cloudflare") {
                                            dnsCmd = "nmcli con mod \"$(nmcli -t -f NAME con show --active | head -n1)\" ipv4.dns '1.1.1.1 1.0.0.1' ipv4.ignore-auto-dns yes && nmcli con up \"$(nmcli -t -f NAME con show --active | head -n1)\""
                                        } else if (modelData === "Google") {
                                            dnsCmd = "nmcli con mod \"$(nmcli -t -f NAME con show --active | head -n1)\" ipv4.dns '8.8.8.8 8.8.4.4' ipv4.ignore-auto-dns yes && nmcli con up \"$(nmcli -t -f NAME con show --active | head -n1)\""
                                        } else if (modelData === "DHCP") {
                                            dnsCmd = "nmcli con mod \"$(nmcli -t -f NAME con show --active | head -n1)\" ipv4.dns '' ipv4.ignore-auto-dns no && nmcli con up \"$(nmcli -t -f NAME con show --active | head -n1)\""
                                        } else if (modelData === "Custom") {
                                            dnsCmd = "kitty -e sh -c 'echo -n \"Enter DNS (e.g. 9.9.9.9): \"; read dns; nmcli con mod \"$(nmcli -t -f NAME con show --active | head -n1)\" ipv4.dns \"$dns\" ipv4.ignore-auto-dns yes && nmcli con up \"$(nmcli -t -f NAME con show --active | head -n1)\"'"
                                        }
                                        if (dnsCmd !== "") {
                                            Quickshell.execDetached(["sh", "-c", dnsCmd])
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // Networks Lists Section
                ColumnLayout {
                    visible: networkRoot.wifiEnabled
                    Layout.fillWidth: true
                    spacing: 6

                    Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Colors.c(0) }

                    // Known Networks Section
                    Text {
                        text: "KNOWN NETWORKS"
                        color: Colors.c(8)
                        font.pixelSize: 9
                        font.bold: true
                        font.family: "Hack Nerd Font"
                    }

                    Repeater {
                        model: networkRoot.knownNetworks

                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: 36
                            radius: 4
                            color: Colors.c(0)

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 8
                                spacing: 8

                                Text { text: "󰤨"; color: Colors.c(7); font.pixelSize: 14; font.family: "Hack Nerd Font" }

                                ColumnLayout {
                                    spacing: 0
                                    Text { text: modelData.ssid; color: Colors.c(7); font.pixelSize: 11; font.bold: true; font.family: "Hack Nerd Font" }
                                    Text { text: "Connected"; color: Colors.c(8); font.pixelSize: 9; font.family: "Hack Nerd Font" }
                                }

                                Item { Layout.fillWidth: true }

                                Text { text: "󰌾"; color: Colors.c(8); font.pixelSize: 11; font.family: "Hack Nerd Font" }
                            }
                        }
                    }

                    // Other Networks Section
                    Text {
                        text: "OTHER NETWORKS"
                        color: Colors.c(8)
                        font.pixelSize: 9
                        font.bold: true
                        font.family: "Hack Nerd Font"
                    }

                    Repeater {
                        model: networkRoot.otherNetworks

                        Item {
                            Layout.fillWidth: true
                            implicitHeight: 22

                            RowLayout {
                                anchors.fill: parent
                                spacing: 8

                                Text { text: "󰤨"; color: Colors.c(8); font.pixelSize: 12; font.family: "Hack Nerd Font" }
                                Text { text: modelData; color: Colors.c(7); font.pixelSize: 10; font.family: "Hack Nerd Font" }
                                Item { Layout.fillWidth: true }
                                Text { text: "󰌾"; color: Colors.c(8); font.pixelSize: 10; font.family: "Hack Nerd Font" }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    var script = "if ! nmcli dev wifi connect '" + modelData + "' 2>/dev/null; then " +
                                                 "echo 'Password required for " + modelData + ":'; " +
                                                 "read -s pass; " +
                                                 "nmcli dev wifi connect '" + modelData + "' password \"$pass\"; " +
                                                 "fi"
                                    Quickshell.execDetached(["sh", "-c", "kitty -e sh -c \"" + script + "\" || nmcli dev wifi connect '" + modelData + "'"])
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
