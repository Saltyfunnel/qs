import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import QtQuick
import QtQuick.Layouts

Item {
    id: ccRoot

    implicitWidth: 28
    implicitHeight: 28

    property string homeDir: ""
    property var player: Mpris.players.values[0] ?? null
    readonly property bool hasMedia: player !== null && (player.trackTitle !== "" || player.playbackState === MprisPlaybackState.Playing)

    property var sink: Pipewire.defaultAudioSink
    property int brightnessLevel: 100

    // Display state
    property bool displayExpanded: false
    property string selectedMonitor: "eDP-1"
    readonly property var resolutionPresets: [
        { label: "1920x1080 @ 144Hz", w: 1920, h: 1080, r: 144 },
        { label: "1920x1080 @ 60Hz",  w: 1920, h: 1080, r: 60 },
        { label: "2560x1440 @ 165Hz", w: 2560, h: 1440, r: 165 },
        { label: "2560x1440 @ 144Hz", w: 2560, h: 1440, r: 144 },
        { label: "2560x1440 @ 60Hz",  w: 2560, h: 1080, r: 60 }
    ]

    Process {
        id: monitorFetcher
        command: ["bash", "-c", "hyprctl -j monitors | jq -r '.[] | select(.focused==true) | .name' 2>/dev/null || hyprctl -j monitors | jq -r '.[0].name'"]
        stdout: StdioCollector {
            onStreamFinished: {
                var name = text.trim()
                if (name.length > 0) ccRoot.selectedMonitor = name
            }
        }
    }

    function applyResolution(mon, width, height, refresh) {
        var newMode = width + "x" + height + "@" + refresh
        var luaCmd = "hyprctl eval 'hl.monitor({ output = \"" + mon + "\", mode = \"" + newMode + "\", position = \"auto\", scale = 1 })'"
        Quickshell.execDetached(["bash", "-c", luaCmd])
    }

    // Network state
    property bool networkExpanded: false
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
    property bool wifiEnabled: true
    property string selectedDns: "DHCP"
    property var knownNetworks: []
    property var otherNetworks: []
    property real lastRxBytes: 0
    property real lastTxBytes: 0
    property real lastSpeedCheckTime: 0

    // Bluetooth state
    property bool btExpanded: false
    property bool btPowered: true
    property var connectedDevices: []
    property var availableDevices: []

    // System info state
    property int cpuUsage: 0
    property int memUsage: 0
    property string memText: "0GB / 0GB"
    property int diskUsage: 0
    property string diskText: "0GB / 0GB"
    property string uptimeText: "0m"

    // Power/battery state
    property bool powerExpanded: false
    property bool hasBattery: false
    property int battPct: 0
    property bool charging: false
    property string batterySize: "--"
    property string timeLeft: "--"
    property string chargeCycles: "--"
    property string wattage: "--"
    property string activeProfile: "balanced"

    // Dynamic Hardware Battery Detection
    Process {
        id: batDetectProc
        command: ["sh", "-c", "ls /sys/class/power_supply/BAT* 2>/dev/null | head -n1"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                ccRoot.hasBattery = text.trim().length > 0
            }
        }
    }

    // Update state
    property int pacmanCount: 0
    property int aurCount: 0
    readonly property int updateCount: pacmanCount + aurCount

    // Wallpaper state
    property string currentWallpaper: ""
    property var wallpaperList: []

    function rescanWallpapers() {
        folderScanner.rawOutput = ""
        folderScanner.running = false
        folderScanner.running = true
    }

    function setRandomWallpaper() {
        if (ccRoot.wallpaperList.length === 0) return
        var randomIndex = Math.floor(Math.random() * ccRoot.wallpaperList.length)
        applyWallpaper(ccRoot.wallpaperList[randomIndex])
    }

    function applyWallpaper(filePath) {
        ccRoot.currentWallpaper = filePath
        wallpaperRunner.selectedPath = filePath
        wallpaperRunner.running = false
        wallpaperRunner.running = true
    }

    Process {
        id: folderScanner
        command: [
            "bash", "-c",
            "find \"$HOME/Pictures/Wallpapers\" -type f \\( -iname \"*.png\" -o -iname \"*.jpg\" -o -iname \"*.jpeg\" -o -iname \"*.webp\" \\) -printf \"%T@ %p\n\" 2>/dev/null | sort -nr | cut -d' ' -f2-"
        ]
        property string rawOutput: ""
        stdout: SplitParser {
            onRead: data => { folderScanner.rawOutput += data + "\n" }
        }
        onExited: (code, status) => {
            if (folderScanner.rawOutput.trim().length > 0) {
                var lines = folderScanner.rawOutput.trim().split("\n").filter(l => l.length > 0)
                ccRoot.wallpaperList = lines
                if (ccRoot.currentWallpaper === "" && lines.length > 0) ccRoot.currentWallpaper = lines[0]
            } else {
                ccRoot.wallpaperList = []
            }
        }
    }

    Process {
        id: wallpaperRunner
        property string selectedPath: ""
        command: ["bash", "-c", "~/.config/scripts/setwall.sh \"" + selectedPath + "\""]
    }

    // Screenshot state
    function shootScreenshot(mode) {
        let cmd = ""
        const dir = "~/Pictures/Screenshots"
        const file = dir + "/screenshot_$(date +%Y%m%d_%H%M%S).png"

        if (mode === "full") {
            cmd = "mkdir -p " + dir + " && grim " + file + " && wl-copy < " + file + " && notify-send 'Screenshot' 'Full screen captured'"
        } else if (mode === "region") {
            cmd = "mkdir -p " + dir + " && grim -g \"$(slurp)\" " + file + " && wl-copy < " + file + " && notify-send 'Screenshot' 'Region captured'"
        } else if (mode === "window") {
            cmd = "mkdir -p " + dir + " && grim -g \"$(hyprctl activewindow -j | jq -r '.at[0],.at[1],.size[0],.size[1]' | paste -sd' ' | awk '{print $1\",\"$2\" \"$3\"x\"$4}')\" " + file + " && wl-copy < " + file + " && notify-send 'Screenshot' 'Window captured'"
        }

        Quickshell.execDetached(["bash", "-c", cmd])
        bar.closeActivePopup()
    }

    function shootScreenshotDelayed() {
        bar.closeActivePopup()
        delayNotify.running = true
        delayTimer.running = true
    }

    Process {
        id: delayNotify
        command: ["notify-send", "Screenshot", "Capturing in 3 seconds\u2026"]
    }

    Timer {
        id: delayTimer
        interval: 3000
        repeat: false
        onTriggered: {
            const dir = "~/Pictures/Screenshots"
            const file = dir + "/screenshot_$(date +%Y%m%d_%H%M%S).png"
            const cmd = "mkdir -p " + dir + " && grim " + file + " && wl-copy < " + file + " && notify-send 'Screenshot' 'Full screen captured'"
            Quickshell.execDetached(["bash", "-c", cmd])
        }
    }

    PwObjectTracker { objects: [ccRoot.sink] }

    function formatSpeed(bytesPerSec) {
        if (bytesPerSec < 0) bytesPerSec = 0
        if (bytesPerSec >= 1024 * 1024 * 1024) return (bytesPerSec / (1024 * 1024 * 1024)).toFixed(1) + " GB/s"
        if (bytesPerSec >= 1024 * 1024) return (bytesPerSec / (1024 * 1024)).toFixed(1) + " MB/s"
        if (bytesPerSec >= 1024) return (bytesPerSec / 1024).toFixed(0) + " KB/s"
        return Math.round(bytesPerSec) + " B/s"
    }

    // Network processes
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
                    WIFI_INFO=$(nmcli -t -f active,ssid,signal dev wifi | grep '^yes:' | head -n1)
                    SSID=$(echo \"$WIFI_INFO\" | cut -d: -f2)
                    echo \"TYPE:wifi|DEV:$DEV_NAME|NAME:${SSID:-Wi-Fi}|SUB:Connected|IP:${IP:---}|GW:${GW:---}\"
                fi
            else
                echo \"TYPE:none|DEV:|NAME:Disconnected|SUB:No Active Network|IP:--|GW:--\"
            fi
        "]
        stdout: SplitParser {
            onRead: data => {
                var line = data.trim()
                if (!line) return
                var parts = line.split("|")
                var kv = {}
                for (var i = 0; i < parts.length; i++) {
                    var pair = parts[i].split(":")
                    if (pair.length >= 2) kv[pair[0]] = pair.slice(1).join(":")
                }
                if (kv["TYPE"]) ccRoot.connectionType = kv["TYPE"]
                if (kv["DEV"]) ccRoot.activeDevice = kv["DEV"]
                if (kv["NAME"]) ccRoot.activeName = kv["NAME"]
                if (kv["SUB"]) ccRoot.subStatus = kv["SUB"]
                if (kv["IP"]) ccRoot.ipAddress = kv["IP"]
                if (kv["GW"]) ccRoot.gateway = kv["GW"]
            }
        }
    }

    Process {
        id: pingFetcher
        command: ["sh", "-c", "ping -c 2 -W 1 1.1.1.1 2>/dev/null | awk '/packet loss/ {print $6} /rtt/ {print $4}'"]
        stdout: SplitParser {
            onRead: data => {
                var lines = data.trim().split("\n")
                if (lines.length >= 1 && lines[0].includes("%")) ccRoot.packetLoss = lines[0]
                if (lines.length >= 2) {
                    var parts = lines[1].split("/")
                    if (parts.length >= 2) {
                        var val = parseFloat(parts[1])
                        ccRoot.pingMs = !isNaN(val) ? Math.round(val) + " ms" : "--"
                    }
                }
            }
        }
    }

    Process {
        id: trafficFetcher
        command: ["sh", "-c", "
            if [ -n \"" + ccRoot.activeDevice + "\" ]; then
                RX=$(cat /sys/class/net/" + ccRoot.activeDevice + "/statistics/rx_bytes 2>/dev/null || echo 0)
                TX=$(cat /sys/class/net/" + ccRoot.activeDevice + "/statistics/tx_bytes 2>/dev/null || echo 0)
                echo \"$RX $TX\"
            else
                echo \"0 0\"
            fi
        "]
        stdout: SplitParser {
            onRead: data => {
                var parts = data.trim().split(/\s+/)
                if (parts.length >= 2) {
                    var rx = parseFloat(parts[0])
                    var tx = parseFloat(parts[1])
                    var currentTime = Date.now()
                    if (ccRoot.lastSpeedCheckTime > 0) {
                        var timeDiff = (currentTime - ccRoot.lastSpeedCheckTime) / 1000.0
                        if (timeDiff > 0) {
                            ccRoot.rxRate = ccRoot.formatSpeed((rx - ccRoot.lastRxBytes) / timeDiff)
                            ccRoot.txRate = ccRoot.formatSpeed((tx - ccRoot.lastTxBytes) / timeDiff)
                        }
                    }
                    ccRoot.lastRxBytes = rx
                    ccRoot.lastTxBytes = tx
                    ccRoot.lastSpeedCheckTime = currentTime
                }
            }
        }
    }

    Process {
        id: nearbyFetcher
        command: ["bash", "-c", "nmcli dev wifi rescan 2>/dev/null; nmcli -t -f active,ssid dev wifi list 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = text.trim().split("\n")
                var known = []
                var other = []
                for (var i = 0; i < lines.length; i++) {
                    var line = lines[i].trim()
                    if (!line) continue
                    var idx = line.indexOf(":")
                    if (idx === -1) continue

                    var isActive = line.substring(0, idx) === "yes"
                    var ssid = line.substring(idx + 1).trim()
                    if (!ssid) continue

                    if (isActive) {
                        if (!known.some(e => e.ssid === ssid)) known.push({ ssid: ssid, connected: true })
                    } else {
                        if (other.indexOf(ssid) === -1 && !known.some(e => e.ssid === ssid)) other.push(ssid)
                    }
                }
                ccRoot.knownNetworks = known
                ccRoot.otherNetworks = other
            }
        }
    }

    Process {
        id: radioFetcher
        command: ["nmcli", "radio", "wifi"]
        stdout: SplitParser { onRead: data => ccRoot.wifiEnabled = (data.trim() === "enabled") }
    }

    Process {
        id: dnsFetcher
        command: ["sh", "-c", "nmcli -t -f IP4.DNS dev show 2>/dev/null | head -n 1 | cut -d: -f2"]
        stdout: SplitParser {
            onRead: data => {
                var dns = data.trim()
                if (dns === "1.1.1.1" || dns === "1.0.0.1") ccRoot.selectedDns = "Cloudflare"
                else if (dns === "8.8.8.8" || dns === "8.8.4.4") ccRoot.selectedDns = "Google"
                else if (dns !== "") ccRoot.selectedDns = "Custom"
                else ccRoot.selectedDns = "DHCP"
            }
        }
    }

    // Bluetooth processes
    Process {
        id: btPowerFetcher
        command: ["sh", "-c", "bluetoothctl show | grep -q 'Powered: yes' && echo yes || echo no"]
        stdout: StdioCollector { onStreamFinished: ccRoot.btPowered = text.trim() === "yes" }
    }

    Process {
        id: btDevicesFetcher
        command: ["sh", "-c", "bluetoothctl devices"]
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = text.trim().split("\n").filter(l => l.length > 0)
                var avail = []
                for (var i = 0; i < lines.length; i++) {
                    var parts = lines[i].trim().split(/\s+/)
                    if (parts.length >= 3 && parts[0] === "Device") {
                        avail.push({ mac: parts[1], name: parts.slice(2).join(" ") })
                    }
                }
                ccRoot.availableDevices = avail
            }
        }
    }

    Process {
        id: btConnectedFetcher
        command: ["sh", "-c", "bluetoothctl info | grep -E 'Device|Connected:'"]
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = text.trim().split("\n")
                var conn = []
                var currentMac = "", currentName = ""
                for (var i = 0; i < lines.length; i++) {
                    var line = lines[i].trim()
                    if (line.startsWith("Device")) {
                        var parts = line.split(/\s+/)
                        currentMac = parts[1]
                        currentName = parts.slice(2).join(" ")
                    } else if (line.indexOf("Connected: yes") !== -1 && currentMac !== "") {
                        conn.push({ mac: currentMac, name: currentName })
                    }
                }
                ccRoot.connectedDevices = conn
            }
        }
    }

    Process { id: toggleBtProcess }
    Process { id: btConnectProcess }

    // System info processes
    Process {
        id: cpuProc
        command: ["bash", "-c", "top -bn1 | grep 'Cpu(s)' | sed 's/.*, *\\([0-9.]*\\)%* id.*/\\1/' | awk '{print 100 - $1}'"]
        stdout: StdioCollector {
            onStreamFinished: {
                var val = parseFloat(text.trim())
                ccRoot.cpuUsage = isNaN(val) ? 0 : Math.round(val)
            }
        }
    }

    Process {
        id: memProc
        command: ["bash", "-c", "free -m | awk 'NR==2{printf \"%d %.2f %.2f\", $3*100/$2, $3/1024, $2/1024}'"]
        stdout: StdioCollector {
            onStreamFinished: {
                var parts = text.trim().split(" ")
                if (parts.length >= 3) {
                    ccRoot.memUsage = parseInt(parts[0]) || 0
                    ccRoot.memText = parseFloat(parts[1]).toFixed(1) + "G / " + parseFloat(parts[2]).toFixed(1) + "G"
                }
            }
        }
    }

    Process {
        id: diskProc
        command: ["bash", "-c", "df -h / | awk 'NR==2 {print $5, $3, $2}' | tr -d '%'"]
        stdout: StdioCollector {
            onStreamFinished: {
                var parts = text.trim().split(/\s+/)
                if (parts.length >= 3) {
                    ccRoot.diskUsage = parseInt(parts[0]) || 0
                    ccRoot.diskText = parts[1] + " / " + parts[2]
                }
            }
        }
    }

    Process {
        id: uptimeProc
        command: ["bash", "-c", "uptime -p | sed 's/up //'"]
        stdout: StdioCollector { onStreamFinished: ccRoot.uptimeText = text.trim() || "Unknown" }
    }

    // Direct Battery Stats Fetcher
    Process {
        id: statsProc
        command: ["sh", "-c", "
            BAT=$(upower -e | grep -m1 'BAT')
            if [ -n \"$BAT\" ]; then
                upower -i \"$BAT\"
            else
                echo 'percentage: 0%'
            fi
        "]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.split("\n")
                for (const l of lines) {
                    const t = l.trim()
                    if (t.startsWith("percentage:")) {
                        const m = t.match(/([\d.]+)/)
                        if (m) ccRoot.battPct = Math.round(parseFloat(m[1]))
                    } else if (t.startsWith("state:")) {
                        ccRoot.charging = t.includes("charging") && !t.includes("discharging")
                    } else if (t.startsWith("energy-full:")) {
                        const m = t.match(/([\d.]+)\s*Wh/)
                        if (m) ccRoot.batterySize = Math.round(parseFloat(m[1])) + "Wh"
                    } else if (t.startsWith("time to empty:") || t.startsWith("time to full:")) {
                        ccRoot.timeLeft = t.split(":").slice(1).join(":").trim()
                    } else if (t.startsWith("charge-cycles:")) {
                        const v = t.split(":")[1].trim()
                        ccRoot.chargeCycles = v === "N/A" ? "--" : v
                    } else if (t.startsWith("energy-rate:")) {
                        const m = t.match(/([\d.]+)\s*W/)
                        if (m) ccRoot.wattage = parseFloat(m[1]).toFixed(1) + "W"
                    }
                }
            }
        }
    }

    Process {
        id: profileProc
        command: ["bash", "-c", "powerprofilesctl get 2>/dev/null || echo 'balanced'"]
        stdout: StdioCollector { onStreamFinished: ccRoot.activeProfile = text.trim() }
    }

    // Update check
    Process {
        id: updateProc
        command: ["bash", "-c", "checkupdates 2>/dev/null | wc -l; yay -Qua 2>/dev/null | wc -l"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split("\n")
                ccRoot.pacmanCount = parseInt(lines[0]) || 0
                ccRoot.aurCount = parseInt(lines[1]) || 0
            }
        }
    }

    Timer {
        interval: 3600000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: updateProc.running = true
    }

    Process {
        id: upgradeProc
        command: ["kitty", "-e", "yay"]
        onExited: (code, status) => { updateProc.running = true }
    }

    // Shared poll
    Timer {
        id: pollTimer
        interval: 3000
        running: ccPopup.visible
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            statusFetcher.running = false; statusFetcher.running = true
            pingFetcher.running = false; pingFetcher.running = true
            trafficFetcher.running = false; trafficFetcher.running = true
            radioFetcher.running = false; radioFetcher.running = true
            dnsFetcher.running = false; dnsFetcher.running = true
            if (ccRoot.wifiEnabled) { nearbyFetcher.running = false; nearbyFetcher.running = true }
            btPowerFetcher.running = false; btPowerFetcher.running = true
            btDevicesFetcher.running = false; btDevicesFetcher.running = true
            btConnectedFetcher.running = false; btConnectedFetcher.running = true
            cpuProc.running = true
            memProc.running = true
            diskProc.running = true
            uptimeProc.running = true
            batDetectProc.running = true
            if (ccRoot.hasBattery) { statsProc.running = true; profileProc.running = true }
        }
    }

    Process {
        id: homeDirFetcher
        command: ["sh", "-c", "echo $HOME"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: ccRoot.homeDir = text.trim()
        }
    }

    Process {
        id: getBrightnessProcess
        command: ["brightnessctl", "-m", "i"]
        running: true
        stdout: SplitParser {
            onRead: data => {
                var parts = data.split(",")
                if (parts.length >= 4) {
                    var percentageStr = parts[3].replace("%", "").trim()
                    ccRoot.brightnessLevel = parseInt(percentageStr)
                }
            }
        }
    }

    Process {
        id: setBrightnessProcess
        function setLevel(val) {
            command = ["brightnessctl", "s", val + "%"]
            running = true
        }
    }

    Text {
        anchors.centerIn: parent
        text: "\uF013"
        color: Colors.c(0)
        font.pixelSize: 14
        font.family: "Hack Nerd Font"
    }

    Rectangle {
        visible: ccRoot.updateCount > 0
        width: 6
        height: 6
        radius: 3
        color: Colors.c(1)
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: 2
        anchors.rightMargin: 2
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: bar.togglePopup(ccPopup)
    }

    PopupWindow {
        id: ccPopup
        visible: false
        anchor.item: ccRoot
        anchor.rect.x: -300
        anchor.rect.y: ccRoot.height + 8
        grabFocus: true

        implicitWidth: 340
        implicitHeight: mainLayout.implicitHeight + 32
        color: "transparent"

        onVisibleChanged: {
            if (visible) {
                monitorFetcher.running = true
                contentRoot.opacity = 0
                contentRoot.scale = 0.94
                Qt.callLater(function() {
                    contentRoot.opacity = 1
                    contentRoot.scale = 1
                })
            }
        }

        Rectangle {
            id: contentRoot
            anchors.fill: parent
            radius: 12
            color: Colors.bg()
            border.color: Colors.c(1)
            border.width: 2

            opacity: 0
            scale: 0.94
            transformOrigin: Item.Center

            Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
            Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

            ColumnLayout {
                id: mainLayout
                anchors.fill: parent
                anchors.margins: 16
                spacing: 10

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    Rectangle {
                        implicitWidth: 42
                        implicitHeight: 42
                        radius: 21
                        color: Colors.c(0)
                        clip: true

                        Image {
                            id: avatarImg
                            anchors.fill: parent
                            source: ccRoot.homeDir ? "file://" + ccRoot.homeDir + "/.face" : ""
                            fillMode: Image.PreserveAspectCrop
                            visible: status === Image.Ready
                        }

                        Text {
                            anchors.centerIn: parent
                            text: "\uF007"
                            color: Colors.c(8)
                            font.pixelSize: 20
                            font.family: "Hack Nerd Font"
                            visible: avatarImg.status !== Image.Ready
                        }
                    }

                    ColumnLayout {
                        spacing: 0
                        Text {
                            text: "Gerard"
                            color: Colors.c(7)
                            font.bold: true
                            font.pixelSize: 15
                            font.family: "Hack Nerd Font"
                        }
                        Text {
                            text: "CONTROL CENTRE"
                            color: Colors.c(8)
                            font.pixelSize: 9
                            font.bold: true
                            font.family: "Hack Nerd Font"
                        }
                    }

                    Item { Layout.fillWidth: true }

                    Text {
                        text: "\uF03E"
                        color: Colors.c(7)
                        font.pixelSize: 17
                        font.family: "Hack Nerd Font"
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            onClicked: (mouse) => {
                                if (mouse.button === Qt.RightButton) {
                                    ccRoot.setRandomWallpaper()
                                } else {
                                    bar.togglePopup(wallpaperPickerPopup)
                                }
                            }
                        }
                    }

                    Text {
                        text: "\uF030"
                        color: Colors.c(7)
                        font.pixelSize: 17
                        font.family: "Hack Nerd Font"
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: bar.togglePopup(screenshotMenuPopup)
                        }
                    }
                }

                Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Colors.c(8) }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    visible: ccRoot.hasMedia

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10

                        Rectangle {
                            implicitWidth: 52
                            implicitHeight: 52
                            radius: 8
                            color: Colors.c(0)
                            clip: true

                            Image {
                                id: artImg
                                anchors.fill: parent
                                source: ccRoot.player && ccRoot.player.trackArtUrl ? ccRoot.player.trackArtUrl : ""
                                fillMode: Image.PreserveAspectCrop
                                visible: source !== "" && status === Image.Ready
                            }
                            Text {
                                anchors.centerIn: parent
                                text: "󰝚"
                                color: Colors.c(8)
                                font.pixelSize: 20
                                font.family: "Hack Nerd Font"
                                visible: !artImg.visible
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2
                            Text {
                                text: ccRoot.player ? (ccRoot.player.trackTitle || "Unknown title") : "Nothing playing"
                                color: Colors.c(7)
                                font.bold: true
                                font.pixelSize: 12
                                font.family: "Hack Nerd Font"
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                            Text {
                                text: ccRoot.player ? (ccRoot.player.trackArtist || "") : ""
                                color: Colors.c(8)
                                font.pixelSize: 10
                                font.family: "Hack Nerd Font"
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                        }

                        RowLayout {
                            spacing: 14
                            Text {
                                text: "󰒮"
                                color: Colors.c(7)
                                font.pixelSize: 14
                                font.family: "Hack Nerd Font"
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: if (ccRoot.player) ccRoot.player.previous() }
                            }
                            Text {
                                text: ccRoot.player && ccRoot.player.playbackState === MprisPlaybackState.Playing ? "󰏤" : "󰐊"
                                color: Colors.c(1)
                                font.pixelSize: 18
                                font.family: "Hack Nerd Font"
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: if (ccRoot.player) ccRoot.player.togglePlaying() }
                            }
                            Text {
                                text: "󰒭"
                                color: Colors.c(7)
                                font.pixelSize: 14
                                font.family: "Hack Nerd Font"
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: if (ccRoot.player) ccRoot.player.next() }
                            }
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                        height: 5

                        Rectangle { anchors.fill: parent; radius: 3; color: Colors.c(0) }
                        Rectangle {
                            width: (ccRoot.player && ccRoot.player.length > 0)
                                   ? parent.width * (ccRoot.player.position / ccRoot.player.length)
                                   : 0
                            height: parent.height
                            radius: 3
                            color: Colors.c(1)
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: (e) => {
                                if (ccRoot.player && ccRoot.player.length > 0) {
                                    ccRoot.player.position = (e.x / width) * ccRoot.player.length
                                }
                            }
                        }
                    }
                }

                Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Colors.c(8); visible: ccRoot.hasMedia }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            text: {
                                if (!ccRoot.sink || !ccRoot.sink.audio) return "󰓄 Volume"
                                var vol = Math.round(ccRoot.sink.audio.volume * 100)
                                return (ccRoot.sink.audio.muted ? "󰝟" : (vol > 50 ? "󰕾" : "󰖀")) + " Volume"
                            }
                            color: Colors.c(7)
                            font.bold: true
                            font.pixelSize: 12
                            font.family: "Hack Nerd Font"
                        }
                        Item { Layout.fillWidth: true }
                        Text {
                            text: ccRoot.sink && ccRoot.sink.audio ? Math.round(ccRoot.sink.audio.volume * 100) + "%" : "0%"
                            color: Colors.c(1)
                            font.bold: true
                            font.pixelSize: 11
                            font.family: "Hack Nerd Font"
                        }
                    }

                    Rectangle {
                        id: volumeTrack
                        Layout.fillWidth: true
                        implicitHeight: 8
                        radius: 4
                        color: Colors.c(8)

                        Rectangle {
                            width: parent.width * (ccRoot.sink && ccRoot.sink.audio ? ccRoot.sink.audio.volume : 0)
                            height: parent.height
                            radius: 4
                            color: Colors.c(1)
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            onPositionChanged: (mouse) => {
                                if (pressed && ccRoot.sink && ccRoot.sink.audio) {
                                    ccRoot.sink.audio.volume = Math.max(0, Math.min(1, mouse.x / width))
                                }
                            }
                            onPressed: (mouse) => {
                                if (mouse.button === Qt.RightButton) {
                                    if (ccRoot.sink && ccRoot.sink.audio) ccRoot.sink.audio.muted = !ccRoot.sink.audio.muted
                                    return
                                }
                                if (ccRoot.sink && ccRoot.sink.audio) {
                                    ccRoot.sink.audio.volume = Math.max(0, Math.min(1, mouse.x / width))
                                }
                            }
                        }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            text: "󰃟 Brightness"
                            color: Colors.c(7)
                            font.bold: true
                            font.pixelSize: 12
                            font.family: "Hack Nerd Font"
                        }
                        Item { Layout.fillWidth: true }
                        Text {
                            text: ccRoot.brightnessLevel + "%"
                            color: Colors.c(1)
                            font.bold: true
                            font.pixelSize: 11
                            font.family: "Hack Nerd Font"
                        }
                    }

                    Rectangle {
                        id: brightnessTrack
                        Layout.fillWidth: true
                        implicitHeight: 8
                        radius: 4
                        color: Colors.c(8)

                        Rectangle {
                            width: parent.width * (ccRoot.brightnessLevel / 100)
                            height: parent.height
                            radius: 4
                            color: Colors.c(1)
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onPositionChanged: (mouse) => {
                                if (pressed) {
                                    var v = Math.max(5, Math.min(100, Math.round((mouse.x / width) * 100)))
                                    ccRoot.brightnessLevel = v
                                    setBrightnessProcess.setLevel(v)
                                }
                            }
                            onPressed: (mouse) => {
                                var v = Math.max(5, Math.min(100, Math.round((mouse.x / width) * 100)))
                                ccRoot.brightnessLevel = v
                                setBrightnessProcess.setLevel(v)
                            }
                        }
                    }
                }

                Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Colors.c(8) }

                Rectangle {
                    Layout.fillWidth: true
                    radius: 8
                    color: Colors.c(0)
                    implicitHeight: displayCardCol.implicitHeight + 20
                    clip: true

                    Behavior on implicitHeight { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

                    ColumnLayout {
                        id: displayCardCol
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: 10
                        spacing: 8

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 10

                            Text { text: "󰍹"; color: Colors.c(7); font.pixelSize: 18; font.family: "Hack Nerd Font" }
                            Text { text: "Display · " + ccRoot.selectedMonitor; color: Colors.c(7); font.bold: true; font.pixelSize: 12; font.family: "Hack Nerd Font" }
                            Item { Layout.fillWidth: true }
                            Text {
                                text: ccRoot.displayExpanded ? "󰅃" : "󰅀"
                                color: Colors.c(8)
                                font.pixelSize: 12
                                font.family: "Hack Nerd Font"
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: ccRoot.displayExpanded = !ccRoot.displayExpanded }
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 6
                            visible: ccRoot.displayExpanded

                            Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Colors.c(8) }

                            Text {
                                text: "DISPLAY PRESETS"
                                color: Colors.c(8)
                                font.pixelSize: 9
                                font.bold: true
                                font.family: "Hack Nerd Font"
                            }

                            Repeater {
                                model: ccRoot.resolutionPresets
                                delegate: Rectangle {
                                    Layout.fillWidth: true
                                    implicitHeight: 30
                                    radius: 6
                                    color: Colors.bg()

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: 10
                                        anchors.rightMargin: 10

                                        Text { text: modelData.label; color: Colors.c(7); font.pixelSize: 11; font.family: "Hack Nerd Font" }
                                        Item { Layout.fillWidth: true }
                                        Text { text: "Apply"; color: Colors.c(1); font.pixelSize: 10; font.bold: true; font.family: "Hack Nerd Font" }
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: ccRoot.applyResolution(ccRoot.selectedMonitor, modelData.w, modelData.h, modelData.r)
                                    }
                                }
                            }
                        }
                    }
                }

                Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Colors.c(8) }

                Rectangle {
                    Layout.fillWidth: true
                    radius: 8
                    color: Colors.c(0)
                    implicitHeight: netCardCol.implicitHeight + 20
                    clip: true

                    Behavior on implicitHeight { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

                    ColumnLayout {
                        id: netCardCol
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: 10
                        spacing: 8

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 10

                            Text {
                                text: ccRoot.connectionType === "ethernet" ? "󰈀" : (ccRoot.connectionType === "wifi" ? "󰤨" : "󰤮")
                                color: Colors.c(7)
                                font.pixelSize: 18
                                font.family: "Hack Nerd Font"
                            }
                            ColumnLayout {
                                spacing: 0
                                Text { text: ccRoot.activeName; color: Colors.c(7); font.bold: true; font.pixelSize: 12; font.family: "Hack Nerd Font" }
                                Text { text: ccRoot.subStatus; color: Colors.c(8); font.pixelSize: 9; font.family: "Hack Nerd Font" }
                            }
                            Item { Layout.fillWidth: true }
                            Text {
                                text: ccRoot.networkExpanded ? "󰅃" : "󰅀"
                                color: Colors.c(8)
                                font.pixelSize: 12
                                font.family: "Hack Nerd Font"
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: ccRoot.networkExpanded = !ccRoot.networkExpanded
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 8
                            visible: ccRoot.networkExpanded

                            Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Colors.c(8) }

                            GridLayout {
                                Layout.fillWidth: true
                                columns: 2
                                rowSpacing: 3
                                columnSpacing: 10

                                Text { text: "Ping"; color: Colors.c(8); font.pixelSize: 9; font.family: "Hack Nerd Font" }
                                Text { text: ccRoot.pingMs; color: Colors.c(7); font.pixelSize: 9; font.bold: true; font.family: "Hack Nerd Font"; Layout.alignment: Qt.AlignRight }
                                Text { text: "Receiving"; color: Colors.c(8); font.pixelSize: 9; font.family: "Hack Nerd Font" }
                                Text { text: ccRoot.rxRate; color: Colors.c(7); font.pixelSize: 9; font.bold: true; font.family: "Hack Nerd Font"; Layout.alignment: Qt.AlignRight }
                                Text { text: "Sending"; color: Colors.c(8); font.pixelSize: 9; font.family: "Hack Nerd Font" }
                                Text { text: ccRoot.txRate; color: Colors.c(7); font.pixelSize: 9; font.bold: true; font.family: "Hack Nerd Font"; Layout.alignment: Qt.AlignRight }
                                Text { text: "IP Address"; color: Colors.c(8); font.pixelSize: 9; font.family: "Hack Nerd Font" }
                                Text { text: ccRoot.ipAddress; color: Colors.c(7); font.pixelSize: 9; font.bold: true; font.family: "Hack Nerd Font"; Layout.alignment: Qt.AlignRight }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                Text { text: "WI-FI"; color: Colors.c(8); font.pixelSize: 9; font.bold: true; font.family: "Hack Nerd Font" }
                                Item { Layout.fillWidth: true }
                                Rectangle {
                                    implicitWidth: 32
                                    implicitHeight: 16
                                    radius: 8
                                    color: ccRoot.wifiEnabled ? Colors.c(1) : Colors.c(8)
                                    Rectangle {
                                        x: ccRoot.wifiEnabled ? parent.width - width - 2 : 2
                                        y: 2
                                        width: 12; height: 12; radius: 6
                                        color: Colors.bg()
                                        Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.InOutQuad } }
                                    }
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            var cmd = ccRoot.wifiEnabled ? "nmcli radio wifi off" : "nmcli radio wifi on"
                                            Quickshell.execDetached(["sh", "-c", cmd])
                                            ccRoot.wifiEnabled = !ccRoot.wifiEnabled
                                        }
                                    }
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 4
                                visible: ccRoot.wifiEnabled && (ccRoot.knownNetworks.length > 0 || ccRoot.otherNetworks.length > 0)

                                Text { text: "NETWORKS"; color: Colors.c(8); font.pixelSize: 9; font.bold: true; font.family: "Hack Nerd Font" }

                                Repeater {
                                    model: ccRoot.knownNetworks
                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 8
                                        Text { text: "󰤨"; color: Colors.c(7); font.pixelSize: 11; font.family: "Hack Nerd Font" }
                                        Text { text: modelData.ssid; color: Colors.c(7); font.pixelSize: 10; font.bold: true; font.family: "Hack Nerd Font"; Layout.fillWidth: true }
                                        Text { text: "Connected"; color: Colors.c(8); font.pixelSize: 9; font.family: "Hack Nerd Font" }
                                    }
                                }

                                Repeater {
                                    model: ccRoot.otherNetworks
                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 8
                                        Text { text: "󰤨"; color: Colors.c(8); font.pixelSize: 11; font.family: "Hack Nerd Font" }
                                        Text { text: modelData; color: Colors.c(7); font.pixelSize: 10; font.family: "Hack Nerd Font"; Layout.fillWidth: true }
                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                var ssid = modelData.replace(/'/g, "'\\''")
                                                var cmd = "nmcli --ask dev wifi connect '" + ssid + "'; echo 'Press Enter to exit...'; read"

                                                Quickshell.execDetached(["kitty", "-e", "bash", "-c", cmd])
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    radius: 8
                    color: Colors.c(0)
                    implicitHeight: btCardCol.implicitHeight + 20
                    clip: true

                    Behavior on implicitHeight { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

                    ColumnLayout {
                        id: btCardCol
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: 10
                        spacing: 8

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 10

                            Text { text: "󰂯"; color: Colors.c(7); font.pixelSize: 18; font.family: "Hack Nerd Font" }
                            ColumnLayout {
                                spacing: 0
                                Text { text: "Bluetooth"; color: Colors.c(7); font.bold: true; font.pixelSize: 12; font.family: "Hack Nerd Font" }
                                Text {
                                    text: !ccRoot.btPowered ? "Off" : (ccRoot.connectedDevices.length > 0 ? ccRoot.connectedDevices.length + " connected" : "On")
                                    color: Colors.c(8)
                                    font.pixelSize: 9
                                    font.family: "Hack Nerd Font"
                                }
                            }
                            Item { Layout.fillWidth: true }

                            Rectangle {
                                implicitWidth: 32
                                implicitHeight: 16
                                radius: 8
                                color: ccRoot.btPowered ? Colors.c(1) : Colors.c(8)
                                Rectangle {
                                    x: ccRoot.btPowered ? parent.width - width - 2 : 2
                                    y: 2
                                    width: 12; height: 12; radius: 6
                                    color: Colors.bg()
                                    Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.InOutQuad } }
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        var cmd = ccRoot.btPowered ? "bluetoothctl power off" : "bluetoothctl power on"
                                        toggleBtProcess.command = ["sh", "-c", cmd]
                                        toggleBtProcess.running = true
                                        ccRoot.btPowered = !ccRoot.btPowered
                                    }
                                }
                            }

                            Text {
                                text: ccRoot.btExpanded ? "󰅃" : "󰅀"
                                color: Colors.c(8)
                                font.pixelSize: 12
                                font.family: "Hack Nerd Font"
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: ccRoot.btExpanded = !ccRoot.btExpanded
                                }
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 6
                            visible: ccRoot.btExpanded && ccRoot.btPowered

                            Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Colors.c(8) }

                            Repeater {
                                model: ccRoot.connectedDevices
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 8
                                    Text { text: "󰂱"; color: Colors.c(7); font.pixelSize: 11; font.family: "Hack Nerd Font" }
                                    Text { text: modelData.name; color: Colors.c(7); font.pixelSize: 10; font.bold: true; font.family: "Hack Nerd Font"; Layout.fillWidth: true }
                                    Text {
                                        text: "Disconnect"
                                        color: Colors.c(1)
                                        font.pixelSize: 9
                                        font.family: "Hack Nerd Font"
                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                btConnectProcess.command = ["bluetoothctl", "disconnect", modelData.mac]
                                                btConnectProcess.running = true
                                            }
                                        }
                                    }
                                }
                            }

                            Repeater {
                                model: ccRoot.availableDevices
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 8
                                    Text { text: "󰂯"; color: Colors.c(8); font.pixelSize: 11; font.family: "Hack Nerd Font" }
                                    Text { text: modelData.name; color: Colors.c(7); font.pixelSize: 10; font.family: "Hack Nerd Font"; Layout.fillWidth: true }
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            btConnectProcess.command = ["bluetoothctl", "connect", modelData.mac]
                                            btConnectProcess.running = true
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Colors.c(8) }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Repeater {
                        model: [
                            { label: "CPU", value: ccRoot.cpuUsage + "%" },
                            { label: "RAM", value: ccRoot.memText },
                            { label: "DISK", value: ccRoot.diskText }
                        ]
                        delegate: Rectangle {
                            Layout.fillWidth: true
                            radius: 8
                            color: Colors.c(0)
                            implicitHeight: 44
                            Column {
                                anchors.centerIn: parent
                                spacing: 2
                                Text { text: modelData.label; color: Colors.c(8); font.pixelSize: 9; font.family: "Hack Nerd Font"; anchors.horizontalCenter: parent.horizontalCenter }
                                Text { text: modelData.value; color: Colors.c(7); font.bold: true; font.pixelSize: 11; font.family: "Hack Nerd Font"; anchors.horizontalCenter: parent.horizontalCenter }
                            }
                        }
                    }
                }

                Text {
                    text: "󰅐 Uptime " + ccRoot.uptimeText
                    color: Colors.c(8)
                    font.pixelSize: 9
                    font.family: "Hack Nerd Font"
                }

                Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Colors.c(8); visible: ccRoot.hasBattery }

                Rectangle {
                    Layout.fillWidth: true
                    radius: 8
                    color: Colors.c(0)
                    visible: ccRoot.hasBattery
                    implicitHeight: pwrCardCol.implicitHeight + 20
                    clip: true

                    Behavior on implicitHeight { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

                    ColumnLayout {
                        id: pwrCardCol
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: 10
                        spacing: 8

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 10

                            Text {
                                text: ccRoot.charging ? "󱐋" : "󰁹"
                                color: ccRoot.battPct <= 20 ? Colors.c(1) : Colors.c(7)
                                font.pixelSize: 18
                                font.family: "Hack Nerd Font"
                            }
                            ColumnLayout {
                                spacing: 0
                                Text { text: "Battery"; color: Colors.c(7); font.bold: true; font.pixelSize: 12; font.family: "Hack Nerd Font" }
                                Text { text: ccRoot.charging ? "Charging" : "Discharging"; color: Colors.c(8); font.pixelSize: 9; font.family: "Hack Nerd Font" }
                            }
                            Item { Layout.fillWidth: true }
                            Text { text: ccRoot.battPct + "%"; color: Colors.c(7); font.bold: true; font.pixelSize: 14; font.family: "Hack Nerd Font" }
                            Text {
                                text: ccRoot.powerExpanded ? "󰅃" : "󰅀"
                                color: Colors.c(8)
                                font.pixelSize: 12
                                font.family: "Hack Nerd Font"
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: ccRoot.powerExpanded = !ccRoot.powerExpanded }
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: 6
                            radius: 3
                            color: Colors.c(8)
                            Rectangle { width: parent.width * (ccRoot.battPct / 100); height: parent.height; radius: 3; color: Colors.c(1) }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 8
                            visible: ccRoot.powerExpanded

                            Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Colors.c(8) }

                            GridLayout {
                                Layout.fillWidth: true
                                columns: 2
                                rowSpacing: 3
                                columnSpacing: 10

                                Text { text: "Battery size"; color: Colors.c(8); font.pixelSize: 9; font.family: "Hack Nerd Font" }
                                Text { text: ccRoot.batterySize; color: Colors.c(7); font.pixelSize: 9; font.bold: true; font.family: "Hack Nerd Font"; Layout.alignment: Qt.AlignRight }
                                Text { text: "Time left"; color: Colors.c(8); font.pixelSize: 9; font.family: "Hack Nerd Font" }
                                Text { text: ccRoot.timeLeft; color: Colors.c(7); font.pixelSize: 9; font.bold: true; font.family: "Hack Nerd Font"; Layout.alignment: Qt.AlignRight }
                                Text { text: "Charge cycles"; color: Colors.c(8); font.pixelSize: 9; font.family: "Hack Nerd Font" }
                                Text { text: ccRoot.chargeCycles; color: Colors.c(7); font.pixelSize: 9; font.bold: true; font.family: "Hack Nerd Font"; Layout.alignment: Qt.AlignRight }
                                Text { text: "Rate"; color: Colors.c(8); font.pixelSize: 9; font.family: "Hack Nerd Font" }
                                Text { text: ccRoot.wattage; color: Colors.c(7); font.pixelSize: 9; font.bold: true; font.family: "Hack Nerd Font"; Layout.alignment: Qt.AlignRight }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 6

                                Text { text: "POWER PROFILE"; color: Colors.c(8); font.pixelSize: 9; font.bold: true; font.family: "Hack Nerd Font" }

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 4

                                    Repeater {
                                        model: [
                                            { key: "power-saver", label: "Saver" },
                                            { key: "balanced", label: "Balanced" },
                                            { key: "performance", label: "Perf" }
                                        ]
                                        delegate: Rectangle {
                                            Layout.fillWidth: true
                                            implicitHeight: 26
                                            radius: 4
                                            color: ccRoot.activeProfile === modelData.key ? Colors.c(1) : "transparent"
                                            border.color: ccRoot.activeProfile === modelData.key ? Colors.c(1) : Colors.c(8)
                                            border.width: 1
                                            Text {
                                                anchors.centerIn: parent
                                                text: modelData.label
                                                color: ccRoot.activeProfile === modelData.key ? Colors.bg() : Colors.c(8)
                                                font.pixelSize: 9
                                                font.bold: true
                                                font.family: "Hack Nerd Font"
                                            }
                                            MouseArea {
                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    Quickshell.execDetached(["powerprofilesctl", "set", modelData.key])
                                                    ccRoot.activeProfile = modelData.key
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    visible: ccRoot.updateCount > 0
                    radius: 8
                    color: Colors.c(0)
                    implicitHeight: 34

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 8
                        spacing: 8

                        Text { text: "\uF0AB"; color: Colors.c(1); font.pixelSize: 13; font.family: "Hack Nerd Font" }
                        Text {
                            text: ccRoot.pacmanCount + " pacman \u00b7 " + ccRoot.aurCount + " aur pending"
                            color: Colors.c(8)
                            font.pixelSize: 10
                            font.family: "Hack Nerd Font"
                            Layout.fillWidth: true
                        }
                        Text {
                            text: "\uF021"
                            color: Colors.c(8)
                            font.pixelSize: 12
                            font.family: "Hack Nerd Font"
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: updateProc.running = true
                            }
                        }
                        Text {
                            text: "Upgrade"
                            color: Colors.c(1)
                            font.pixelSize: 10
                            font.bold: true
                            font.family: "Hack Nerd Font"
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    bar.closeActivePopup()
                                    upgradeProc.running = true
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    PopupWindow {
        id: wallpaperPickerPopup
        visible: false
        anchor.window: bar
        anchor.rect.x: (bar.width - wallpaperPickerPopup.implicitWidth) / 2
        anchor.rect.y: (bar.screen.height - wallpaperPickerPopup.implicitHeight) / 2

        grabFocus: true
        implicitWidth: 900
        implicitHeight: 620
        color: "transparent"

        onVisibleChanged: {
            if (visible) ccRoot.rescanWallpapers()
        }

        Rectangle {
            anchors.fill: parent
            radius: 12
            color: Colors.bg()
            border.color: Colors.c(1)
            border.width: 2

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 20
                spacing: 14

                RowLayout {
                    Layout.fillWidth: true

                    Text {
                        text: "Wallpaper picker"
                        color: Colors.c(7)
                        font.pixelSize: 18
                        font.bold: true
                        font.family: "Hack Nerd Font"
                    }

                    Item { Layout.fillWidth: true }

                    Rectangle {
                        implicitWidth: randomRow.implicitWidth + 20
                        implicitHeight: 30
                        radius: 8
                        color: Colors.c(1)

                        RowLayout {
                            id: randomRow
                            anchors.centerIn: parent
                            spacing: 6

                            Text { text: "\uF021"; color: Colors.c(0); font.pixelSize: 14; font.family: "Hack Nerd Font" }
                            Text { text: "Random"; color: Colors.c(0); font.pixelSize: 13; font.bold: true; font.family: "Hack Nerd Font" }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: ccRoot.setRandomWallpaper()
                        }
                    }
                }

                Text {
                    visible: ccRoot.wallpaperList.length === 0
                    text: "No images found in your Wallpapers folder"
                    color: Colors.c(8)
                    font.pixelSize: 13
                    font.family: "Hack Nerd Font"
                    Layout.alignment: Qt.AlignCenter
                }

                GridView {
                    id: grid
                    visible: ccRoot.wallpaperList.length > 0
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    property int columns: Math.max(3, Math.floor(width / 240))
                    cellWidth: width / columns
                    cellHeight: cellWidth * 0.65

                    model: ccRoot.wallpaperList
                    delegate: Item {
                        width: grid.cellWidth
                        height: grid.cellHeight

                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: 6
                            radius: 8
                            color: Colors.c(0)
                            border.color: ccRoot.currentWallpaper === modelData ? Colors.c(1) : Colors.c(8)
                            border.width: ccRoot.currentWallpaper === modelData ? 3 : 1
                            clip: true

                            Image {
                                anchors.fill: parent
                                anchors.margins: 3
                                source: "file://" + modelData
                                cache: false
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: ccRoot.applyWallpaper(modelData)
                            }
                        }
                    }
                }
            }
        }
    }

    PopupWindow {
        id: screenshotMenuPopup
        visible: false
        anchor.window: bar
        anchor.rect.x: bar.width - screenshotMenuPopup.implicitWidth
        anchor.rect.y: bar.implicitHeight + 12
        grabFocus: true
        implicitWidth: 260
        implicitHeight: 270
        color: "transparent"

        Rectangle {
            anchors.fill: parent
            radius: 12
            color: Colors.bg()
            border.color: Colors.c(1)
            border.width: 2

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 18
                spacing: 14

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    Text { text: "\uF030"; color: Colors.c(1); font.pixelSize: 20; font.family: "Hack Nerd Font" }
                    Text { text: "Screenshot"; color: Colors.c(7); font.bold: true; font.pixelSize: 15; font.family: "Hack Nerd Font" }
                }

                Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Colors.c(8) }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    Repeater {
                        model: [
                            { key: "region", icon: "󰆞", label: "Select region" },
                            { key: "window", icon: "󰖯", label: "Active window" },
                            { key: "full", icon: "󰹑", label: "Full screen" },
                            { key: "delayed", icon: "󰥔", label: "Full screen (3s delay)" }
                        ]
                        delegate: Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: 40
                            radius: 8
                            color: rowArea.containsMouse ? Colors.c(0) : "transparent"

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 12
                                spacing: 10

                                Text { text: modelData.icon; color: Colors.c(1); font.pixelSize: 15; font.family: "Hack Nerd Font" }
                                Text { text: modelData.label; color: Colors.c(7); font.pixelSize: 12; font.family: "Hack Nerd Font" }
                                Item { Layout.fillWidth: true }
                            }

                            MouseArea {
                                id: rowArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (modelData.key === "delayed") ccRoot.shootScreenshotDelayed()
                                    else ccRoot.shootScreenshot(modelData.key)
                                }
                            }
                        }
                    }
                }

                Item { Layout.fillHeight: true }

                Text {
                    text: "Saved to ~/Pictures/Screenshots"
                    color: Colors.c(8)
                    font.pixelSize: 9
                    font.family: "Hack Nerd Font"
                }
            }
        }
    }
}
