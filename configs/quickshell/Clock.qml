import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

Item {
    id: clockRoot

    // ============================================================
    // CLOCK / WEATHER / CALENDAR STATE
    // ============================================================
    property string customLocation: "London"

    property var currentDate: new Date()
    property var viewDate: new Date()
    property string timeString: ""
    property string dateString: ""

    property string location: "Loading..."
    property string currentTemp: "--"
    property string condition: "Fetching data..."
    property string iconSymbol: "󰖐"
    property string tempHigh: "--"
    property string tempLow: "--"
    property string humidity: "--%"
    property string windSpeed: "-- km/h"
    property string rawResponse: ""

    implicitWidth: pillLayout.implicitWidth + 16
    implicitHeight: 28

    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            clockRoot.currentDate = new Date()
            clockRoot.timeString = clockRoot.currentDate.toLocaleTimeString(Qt.locale(), "hh:mm")
            clockRoot.dateString = clockRoot.currentDate.toLocaleDateString(Qt.locale(), "ddd d MMM")
        }
    }

    function refreshWeather() {
        clockRoot.rawResponse = ""
        weatherFetcher.running = false
        weatherFetcher.running = true
    }

    Process {
        id: weatherFetcher
        command: ["curl", "-s", "https://wttr.in/" + encodeURIComponent(clockRoot.customLocation) + "?format=j1"]
        running: true

        stdout: SplitParser {
            onRead: data => {
                clockRoot.rawResponse += data
            }
        }

        onExited: (code, status) => {
            if (code === 0 && clockRoot.rawResponse.length > 0) {
                try {
                    var json = JSON.parse(clockRoot.rawResponse)
                    var current = json.current_condition[0]
                    var weather = json.weather[0]
                    var area = json.nearest_area[0]

                    clockRoot.location = area.areaName[0].value
                    clockRoot.currentTemp = current.temp_C + "°C"
                    clockRoot.condition = current.weatherDesc[0].value
                    clockRoot.tempHigh = weather.maxtempC + "°C"
                    clockRoot.tempLow = weather.mintempC + "°C"
                    clockRoot.humidity = current.humidity + "%"
                    clockRoot.windSpeed = current.windspeedKmph + " km/h"
                    clockRoot.iconSymbol = getWeatherIcon(current.weatherCode)
                } catch (e) {
                    console.log("Error parsing weather JSON:", e)
                    clockRoot.condition = "Parse Error"
                }
            } else {
                clockRoot.condition = "Fetch Failed"
            }
        }
    }

    Timer {
        interval: 900000
        running: true
        repeat: true
        onTriggered: clockRoot.refreshWeather()
    }

    function getWeatherIcon(code) {
        var c = parseInt(code)
        if (c === 113) return "󰍛"
        if (c === 116) return "󰖕"
        if (c === 119 || c === 122) return "󰖐"
        if (c >= 200 && c <= 230) return "󰙾"
        if (c >= 263 && c <= 308) return "󰖗"
        if (c >= 323 && c <= 377) return "󰼶"
        return "󰖐"
    }

    function getISOWeek(date) {
        var target = new Date(date.valueOf())
        var dayNr = (date.getDay() + 6) % 7
        target.setDate(target.getDate() - dayNr + 3)
        var firstThursday = target.valueOf()
        target.setMonth(0, 1)
        if (target.getDay() !== 4) {
            target.setMonth(0, 1 + ((4 - target.getDay() + 7) % 7))
        }
        return 1 + Math.ceil((firstThursday - target) / 604800000)
    }

    function getCalendarDays(year, month) {
        var days = []
        var firstDay = new Date(year, month, 1)
        var startDayOfWeek = firstDay.getDay()
        var startDate = new Date(year, month, 1 - startDayOfWeek)

        for (var i = 0; i < 42; i++) {
            var cellDate = new Date(startDate.getFullYear(), startDate.getMonth(), startDate.getDate() + i)
            var isCurrentMonth = cellDate.getMonth() === month
            var isToday = cellDate.toDateString() === clockRoot.currentDate.toDateString()

            days.push({
                "dayNumber": cellDate.getDate(),
                "date": cellDate,
                "isCurrentMonth": isCurrentMonth,
                "isToday": isToday,
                "weekNum": getISOWeek(cellDate)
            })
        }
        return days
    }

    function formatTime(seconds) {
        if (isNaN(seconds) || seconds < 0) return "0:00"
        var mins = Math.floor(seconds / 60)
        var secs = Math.floor(seconds % 60)
        return mins + ":" + (secs < 10 ? "0" : "") + secs
    }

    // ============================================================
    // CONTROL CENTRE STATE
    // ============================================================
    property string homeDir: ""
    property var player: Mpris.players.values[0] ?? null
    readonly property bool hasMedia: player !== null && (player.trackTitle !== "" || player.playbackState === MprisPlaybackState.Playing)

    property var sink: Pipewire.defaultAudioSink
    property int brightnessLevel: 100

    property bool displayExpanded: false
    property string selectedMonitor: "eDP-1"
    readonly property var resolutionPresets: [
        { label: "1920x1080 @ 144Hz", w: 1920, h: 1080, r: 144 },
        { label: "1920x1080 @ 60Hz",  w: 1920, h: 1080, r: 60 },
        { label: "2560x1440 @ 165Hz", w: 2560, h: 1440, r: 165 },
        { label: "2560x1440 @ 144Hz", w: 2560, h: 1440, r: 144 },
        { label: "2560x1440 @ 60Hz",  w: 2560, h: 1440, r: 60 }
    ]

    Process {
        id: monitorFetcher
        command: ["bash", "-c", "hyprctl -j monitors | jq -r '.[] | select(.focused==true) | .name' 2>/dev/null || hyprctl -j monitors | jq -r '.[0].name'"]
        stdout: StdioCollector {
            onStreamFinished: {
                var name = text.trim()
                if (name.length > 0) clockRoot.selectedMonitor = name
            }
        }
    }

    function applyResolution(mon, width, height, refresh) {
        var newMode = width + "x" + height + "@" + refresh
        var cmd = "hyprctl keyword monitor \"" + mon + "," + newMode + ",auto,1\""
        Quickshell.execDetached(["bash", "-c", cmd])
    }

    // Network State & Actions
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

    function connectWifi(ssid) {
        Quickshell.execDetached(["nmcli", "dev", "wifi", "connect", ssid])
    }

    function applyDns(dnsType) {
        var servers = ""
        if (dnsType === "Cloudflare") servers = "1.1.1.1 1.0.0.1"
        else if (dnsType === "Google") servers = "8.8.8.8 8.8.4.4"

        if (clockRoot.activeName !== "Disconnected" && clockRoot.activeName !== "") {
            var cmd = dnsType === "DHCP"
                ? "nmcli con mod \"" + clockRoot.activeName + "\" ipv4.dns \"\" && nmcli con up \"" + clockRoot.activeName + "\""
                : "nmcli con mod \"" + clockRoot.activeName + "\" ipv4.dns \"" + servers + "\" && nmcli con up \"" + clockRoot.activeName + "\""
            Quickshell.execDetached(["sh", "-c", cmd])
        }
        clockRoot.selectedDns = dnsType
    }

    property bool btPowered: true
    property var connectedDevices: []
    property var availableDevices: []

    property int cpuUsage: 0
    property int memUsage: 0
    property string memText: "0GB / 0GB"
    property int diskUsage: 0
    property string diskText: "0GB / 0GB"
    property string uptimeText: "0m"

    property bool powerExpanded: false
    property bool hasBattery: false
    property int battPct: 0
    property bool charging: false
    property string batterySize: "--"
    property string timeLeft: "--"
    property string chargeCycles: "--"
    property string wattage: "--"
    property string activeProfile: "balanced"

    Process {
        id: batDetectProc
        command: ["sh", "-c", "ls /sys/class/power_supply/BAT* 2>/dev/null | head -n1"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                clockRoot.hasBattery = text.trim().length > 0
            }
        }
    }

    property int pacmanCount: 0
    property int aurCount: 0
    readonly property int updateCount: pacmanCount + aurCount

    property string currentWallpaper: ""
    property var wallpaperList: []

    function rescanWallpapers() {
        folderScanner.rawOutput = ""
        folderScanner.running = false
        folderScanner.running = true
    }

    function setRandomWallpaper() {
        if (clockRoot.wallpaperList.length === 0) return
        var randomIndex = Math.floor(Math.random() * clockRoot.wallpaperList.length)
        applyWallpaper(clockRoot.wallpaperList[randomIndex])
    }

    function applyWallpaper(filePath) {
        clockRoot.currentWallpaper = filePath
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
                clockRoot.wallpaperList = lines
                if (clockRoot.currentWallpaper === "" && lines.length > 0) clockRoot.currentWallpaper = lines[0]
            } else {
                clockRoot.wallpaperList = []
            }
        }
    }

    Process {
        id: wallpaperRunner
        property string selectedPath: ""
        command: ["bash", "-c", "~/.config/scripts/setwall.sh \"" + selectedPath + "\""]
    }

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
        command: ["notify-send", "Screenshot", "Capturing in 3 seconds…"]
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

    PwObjectTracker { objects: [clockRoot.sink] }

    function formatSpeed(bytesPerSec) {
        if (bytesPerSec < 0) bytesPerSec = 0
        if (bytesPerSec >= 1024 * 1024 * 1024) return (bytesPerSec / (1024 * 1024 * 1024)).toFixed(1) + " GB/s"
        if (bytesPerSec >= 1024 * 1024) return (bytesPerSec / (1024 * 1024)).toFixed(1) + " MB/s"
        if (bytesPerSec >= 1024) return (bytesPerSec / 1024).toFixed(0) + " KB/s"
        return Math.round(bytesPerSec) + " B/s"
    }

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
                    WIFI_INFO=$(nmcli -t -f active,ssid dev wifi | grep '^yes:' | head -n1)
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
                if (kv["TYPE"]) clockRoot.connectionType = kv["TYPE"]
                if (kv["DEV"]) clockRoot.activeDevice = kv["DEV"]
                if (kv["NAME"]) clockRoot.activeName = kv["NAME"]
                if (kv["SUB"]) clockRoot.subStatus = kv["SUB"]
                if (kv["IP"]) clockRoot.ipAddress = kv["IP"]
                if (kv["GW"]) clockRoot.gateway = kv["GW"]
            }
        }
    }

    Process {
        id: pingFetcher
        command: ["sh", "-c", "ping -c 2 -W 1 1.1.1.1 2>/dev/null | awk '/packet loss/ {print $6} /rtt/ {print $4}'"]
        stdout: SplitParser {
            onRead: data => {
                var lines = data.trim().split("\n")
                if (lines.length >= 1 && lines[0].includes("%")) clockRoot.packetLoss = lines[0]
                if (lines.length >= 2) {
                    var parts = lines[1].split("/")
                    if (parts.length >= 2) {
                        var val = parseFloat(parts[1])
                        clockRoot.pingMs = !isNaN(val) ? Math.round(val) + " ms" : "--"
                    }
                }
            }
        }
    }

    Process {
        id: trafficFetcher
        command: ["sh", "-c", "
            if [ -n \"" + clockRoot.activeDevice + "\" ]; then
                RX=$(cat /sys/class/net/" + clockRoot.activeDevice + "/statistics/rx_bytes 2>/dev/null || echo 0)
                TX=$(cat /sys/class/net/" + clockRoot.activeDevice + "/statistics/tx_bytes 2>/dev/null || echo 0)
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
                    if (clockRoot.lastSpeedCheckTime > 0) {
                        var timeDiff = (currentTime - clockRoot.lastSpeedCheckTime) / 1000.0
                        if (timeDiff > 0) {
                            clockRoot.rxRate = clockRoot.formatSpeed((rx - clockRoot.lastRxBytes) / timeDiff)
                            clockRoot.txRate = clockRoot.formatSpeed((tx - clockRoot.lastTxBytes) / timeDiff)
                        }
                    }
                    clockRoot.lastRxBytes = rx
                    clockRoot.lastTxBytes = tx
                    clockRoot.lastSpeedCheckTime = currentTime
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
                clockRoot.knownNetworks = known
                clockRoot.otherNetworks = other
            }
        }
    }

    Process {
        id: radioFetcher
        command: ["nmcli", "radio", "wifi"]
        stdout: SplitParser { onRead: data => clockRoot.wifiEnabled = (data.trim() === "enabled") }
    }

    Process {
        id: dnsFetcher
        command: ["sh", "-c", "nmcli -t -f IP4.DNS dev show 2>/dev/null | head -n 1 | cut -d: -f2"]
        stdout: SplitParser {
            onRead: data => {
                var dns = data.trim()
                if (dns === "1.1.1.1" || dns === "1.0.0.1") clockRoot.selectedDns = "Cloudflare"
                else if (dns === "8.8.8.8" || dns === "8.8.4.4") clockRoot.selectedDns = "Google"
                else if (dns !== "") clockRoot.selectedDns = "Custom"
                else clockRoot.selectedDns = "DHCP"
            }
        }
    }

    Process {
        id: btPowerFetcher
        command: ["sh", "-c", "bluetoothctl show | grep -q 'Powered: yes' && echo yes || echo no"]
        stdout: StdioCollector { onStreamFinished: clockRoot.btPowered = text.trim() === "yes" }
    }

    Process {
        id: btScanProcess
        command: ["sh", "-c", "bluetoothctl --timeout 5 scan le >/dev/null 2>&1 &"]
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
                        var mac = parts[1]
                        var name = parts.slice(2).join(" ")
                        if (!clockRoot.connectedDevices.some(d => d.mac === mac)) {
                            avail.push({ mac: mac, name: name })
                        }
                    }
                }
                clockRoot.availableDevices = avail
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
                clockRoot.connectedDevices = conn
            }
        }
    }

    Process { id: toggleBtProcess }
    Process { id: btConnectProcess }

    Process {
        id: cpuProc
        command: ["bash", "-c", "top -bn1 | grep 'Cpu(s)' | sed 's/.*, *\\([0-9.]*\\)%* id.*/\\1/' | awk '{print 100 - $1}'"]
        stdout: StdioCollector {
            onStreamFinished: {
                var val = parseFloat(text.trim())
                clockRoot.cpuUsage = isNaN(val) ? 0 : Math.round(val)
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
                    clockRoot.memUsage = parseInt(parts[0]) || 0
                    clockRoot.memText = parseFloat(parts[1]).toFixed(1) + "G / " + parseFloat(parts[2]).toFixed(1) + "G"
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
                    clockRoot.diskUsage = parseInt(parts[0]) || 0
                    clockRoot.diskText = parts[1] + " / " + parts[2]
                }
            }
        }
    }

    Process {
        id: uptimeProc
        command: ["bash", "-c", "uptime -p | sed 's/up //'"]
        stdout: StdioCollector { onStreamFinished: clockRoot.uptimeText = text.trim() || "Unknown" }
    }

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
                        if (m) clockRoot.battPct = Math.round(parseFloat(m[1]))
                    } else if (t.startsWith("state:")) {
                        clockRoot.charging = t.includes("charging") && !t.includes("discharging")
                    } else if (t.startsWith("energy-full:")) {
                        const m = t.match(/([\d.]+)\s*Wh/)
                        if (m) clockRoot.batterySize = Math.round(parseFloat(m[1])) + "Wh"
                    } else if (t.startsWith("time to empty:") || t.startsWith("time to full:")) {
                        clockRoot.timeLeft = t.split(":").slice(1).join(":").trim()
                    } else if (t.startsWith("charge-cycles:")) {
                        const v = t.split(":")[1].trim()
                        clockRoot.chargeCycles = v === "N/A" ? "--" : v
                    } else if (t.startsWith("energy-rate:")) {
                        const m = t.match(/([\d.]+)\s*W/)
                        if (m) clockRoot.wattage = parseFloat(m[1]).toFixed(1) + "W"
                    }
                }
            }
        }
    }

    Process {
        id: profileProc
        command: ["bash", "-c", "powerprofilesctl get 2>/dev/null || echo 'balanced'"]
        stdout: StdioCollector { onStreamFinished: clockRoot.activeProfile = text.trim() }
    }

    Process {
        id: updateProc
        command: ["bash", "-c", "checkupdates 2>/dev/null | wc -l; yay -Qua 2>/dev/null | wc -l"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split("\n")
                clockRoot.pacmanCount = parseInt(lines[0]) || 0
                clockRoot.aurCount = parseInt(lines[1]) || 0
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
            if (clockRoot.wifiEnabled) { nearbyFetcher.running = false; nearbyFetcher.running = true }
            btPowerFetcher.running = false; btPowerFetcher.running = true
            btConnectedFetcher.running = false; btConnectedFetcher.running = true
            btDevicesFetcher.running = false; btDevicesFetcher.running = true
            cpuProc.running = true
            memProc.running = true
            diskProc.running = true
            uptimeProc.running = true
            batDetectProc.running = true
            if (clockRoot.hasBattery) { statsProc.running = true; profileProc.running = true }
        }
    }

    Process {
        id: homeDirFetcher
        command: ["sh", "-c", "echo $HOME"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: clockRoot.homeDir = text.trim()
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
                    clockRoot.brightnessLevel = parseInt(percentageStr)
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

    // ============================================================
    // DASHBOARD CONFIG
    // ============================================================
    property string activeTab: "Dashboard"
    readonly property int popupWidth: 780

    function pywalCardBg(colorIndex) {
        var baseColor = Colors.c(colorIndex)
        return Qt.tint(Colors.bg(), Qt.rgba(baseColor.r, baseColor.g, baseColor.b, 0.35))
    }

    // ============================================================
    // BAR PILL TRIGGER
    // ============================================================
    Rectangle {
        id: mainPill
        anchors.verticalCenter: parent.verticalCenter
        implicitWidth: pillLayout.implicitWidth + 16
        implicitHeight: 28
        radius: 14
        color: Colors.c(1)

        RowLayout {
            id: pillLayout
            anchors.centerIn: parent
            spacing: 10

            Text {
                text: clockRoot.iconSymbol
                color: Colors.c(0)
                font.pixelSize: 15
                font.family: "Hack Nerd Font"
            }
            Text {
                text: clockRoot.currentTemp
                color: Colors.c(0)
                font.pixelSize: 13
                font.bold: true
                font.family: "Hack Nerd Font"
            }

            Rectangle {
                implicitWidth: 1
                implicitHeight: 14
                color: Qt.tint(Colors.c(0), Qt.rgba(0, 0, 0, 0.4))
            }

            Text {
                text: clockRoot.timeString + "  " + clockRoot.dateString
                color: Colors.c(0)
                font.pixelSize: 13
                font.bold: true
                font.family: "Hack Nerd Font"
            }
        }

        Rectangle {
            visible: clockRoot.updateCount > 0
            width: 8
            height: 8
            radius: 4
            color: Colors.c(4)
            border.color: Colors.c(1)
            border.width: 1
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.topMargin: -2
            anchors.rightMargin: -2
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                clockRoot.viewDate = new Date()
                monitorFetcher.running = true
                bar.togglePopup(ccPopup)
            }
        }
    }

    // ============================================================
    // CAELESTIA POPUP OVERLAY LAYOUT
    // ============================================================
    PopupWindow {
        id: ccPopup
        visible: false
        anchor.item: clockRoot
        anchor.rect.x: (clockRoot.implicitWidth - ccPopup.implicitWidth) / 2
        anchor.rect.y: clockRoot.height + 10

        grabFocus: true

        implicitWidth: clockRoot.popupWidth
        implicitHeight: mainLayout.implicitHeight + 40
        color: "transparent"

        Behavior on implicitHeight { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

        onVisibleChanged: {
            if (visible) {
                monitorFetcher.running = true
                contentRoot.opacity = 0
                contentRoot.scale = 0.95
                Qt.callLater(function() {
                    contentRoot.opacity = 1
                    contentRoot.scale = 1
                })
            } else {
                if (btScanProcess.running) {
                    Quickshell.execDetached(["bluetoothctl", "scan", "off"])
                    btScanProcess.running = false
                }
            }
        }

        Rectangle {
            id: contentRoot
            anchors.fill: parent
            radius: 24
            color: Colors.bg()
            border.color: Colors.c(1)
            border.width: 1.5

            opacity: 0
            scale: 0.95
            transformOrigin: Item.Center

            Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
            Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

            ColumnLayout {
                id: mainLayout
                anchors.fill: parent
                anchors.margins: 20
                spacing: 16

                // ---- TOP NAVIGATION TABS BAR ----
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Repeater {
                        model: ["Dashboard", "Media", "Network/BT", "Performance", "Weather"]
                        delegate: Rectangle {
                            implicitWidth: tabText.implicitWidth + 24
                            implicitHeight: 34
                            radius: 17
                            color: clockRoot.activeTab === modelData ? Colors.c(1) : "transparent"

                            Text {
                                id: tabText
                                anchors.centerIn: parent
                                text: modelData
                                color: clockRoot.activeTab === modelData ? Colors.c(0) : Colors.c(7)
                                font.pixelSize: 13
                                font.bold: clockRoot.activeTab === modelData
                                font.family: "Hack Nerd Font"
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: clockRoot.activeTab = modelData
                            }
                        }
                    }

                    Item { Layout.fillWidth: true }

                    // Quick Action Icons
                    Text {
                        text: "󰸉"
                        color: Colors.c(7)
                        font.pixelSize: 18
                        font.family: "Hack Nerd Font"
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            onClicked: (mouse) => {
                                if (mouse.button === Qt.RightButton) clockRoot.setRandomWallpaper()
                                else bar.togglePopup(wallpaperPickerPopup)
                            }
                        }
                    }

                    Text {
                        text: "󰄄"
                        color: Colors.c(7)
                        font.pixelSize: 18
                        font.family: "Hack Nerd Font"
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: bar.togglePopup(screenshotMenuPopup)
                        }
                    }
                }

                // ================================================
                // TAB 1: DASHBOARD
                // ================================================
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 14
                    visible: clockRoot.activeTab === "Dashboard"

                    GridLayout {
                        Layout.fillWidth: true
                        columns: 3
                        rowSpacing: 12
                        columnSpacing: 12

                        // 1. WEATHER CARD
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 130
                            radius: 18
                            color: clockRoot.pywalCardBg(4)
                            border.color: Colors.c(4)
                            border.width: 1.5

                            ColumnLayout {
                                anchors.centerIn: parent
                                spacing: 4

                                Text {
                                    text: clockRoot.iconSymbol + "  " + clockRoot.currentTemp
                                    font.family: "Hack Nerd Font"
                                    font.pixelSize: 26
                                    font.bold: true
                                    color: Colors.c(7)
                                    Layout.alignment: Qt.AlignHCenter
                                }
                                Text {
                                    text: clockRoot.condition
                                    font.family: "Hack Nerd Font"
                                    font.pixelSize: 13
                                    color: Colors.c(4)
                                    Layout.alignment: Qt.AlignHCenter
                                }
                                Text {
                                    text: clockRoot.location
                                    font.family: "Hack Nerd Font"
                                    font.pixelSize: 11
                                    color: Colors.c(8)
                                    Layout.alignment: Qt.AlignHCenter
                                }
                            }
                        }

                        // 2. PROFILE CARD
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 130
                            radius: 18
                            color: clockRoot.pywalCardBg(1)
                            border.color: Colors.c(1)
                            border.width: 1.5

                            RowLayout {
                                anchors.centerIn: parent
                                spacing: 14

                                Rectangle {
                                    implicitWidth: 50
                                    implicitHeight: 50
                                    radius: 25
                                    color: Colors.bg()
                                    clip: true

                                    Image {
                                        id: avatarImg
                                        anchors.fill: parent
                                        source: clockRoot.homeDir ? "file://" + clockRoot.homeDir + "/.face" : ""
                                        fillMode: Image.PreserveAspectCrop
                                        visible: status === Image.Ready
                                    }

                                    Text {
                                        anchors.centerIn: parent
                                        text: "󰄛"
                                        color: Colors.c(1)
                                        font.pixelSize: 24
                                        font.family: "Hack Nerd Font"
                                        visible: avatarImg.status !== Image.Ready
                                    }
                                }

                                ColumnLayout {
                                    spacing: 4
                                    Text {
                                        text: System.user || "User"
                                        color: Colors.c(7)
                                        font.bold: true
                                        font.pixelSize: 14
                                        font.family: "Hack Nerd Font"
                                    }
                                    Text {
                                        text: "󰅐 up " + clockRoot.uptimeText
                                        color: Colors.c(8)
                                        font.pixelSize: 12
                                        font.family: "Hack Nerd Font"
                                    }
                                }
                            }
                        }

                        // 3. QUICK TOGGLES CARD
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 130
                            radius: 18
                            color: clockRoot.pywalCardBg(2)
                            border.color: Colors.c(2)
                            border.width: 1.5

                            GridLayout {
                                anchors.centerIn: parent
                                columns: 2
                                rowSpacing: 8
                                columnSpacing: 8

                                Repeater {
                                    model: [
                                        { icon: "󰤨", active: clockRoot.wifiEnabled },
                                        { icon: "󰂯", active: clockRoot.btPowered },
                                        { icon: clockRoot.sink && clockRoot.sink.audio && clockRoot.sink.audio.muted ? "󰝟" : "󰕾", active: !(clockRoot.sink && clockRoot.sink.audio && clockRoot.sink.audio.muted) },
                                        { icon: "󰈐", active: clockRoot.activeProfile !== "power-saver" }
                                    ]
                                    delegate: Rectangle {
                                        implicitWidth: 44
                                        implicitHeight: 44
                                        radius: 14
                                        color: modelData.active ? Colors.c(1) : Colors.bg()

                                        Text {
                                            anchors.centerIn: parent
                                            text: modelData.icon
                                            color: modelData.active ? Colors.c(0) : Colors.c(7)
                                            font.pixelSize: 17
                                            font.family: "Hack Nerd Font"
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                switch (index) {
                                                    case 0:
                                                        Quickshell.execDetached(["sh", "-c", clockRoot.wifiEnabled ? "nmcli radio wifi off" : "nmcli radio wifi on"])
                                                        clockRoot.wifiEnabled = !clockRoot.wifiEnabled
                                                        break
                                                    case 1:
                                                        toggleBtProcess.command = ["sh", "-c", clockRoot.btPowered ? "bluetoothctl power off" : "bluetoothctl power on; bluetoothctl pairable on"]
                                                        toggleBtProcess.running = true
                                                        clockRoot.btPowered = !clockRoot.btPowered
                                                        break
                                                    case 2:
                                                        if (clockRoot.sink && clockRoot.sink.audio) clockRoot.sink.audio.muted = !clockRoot.sink.audio.muted
                                                        break
                                                    case 3:
                                                        var next = clockRoot.activeProfile === "performance" ? "power-saver" : (clockRoot.activeProfile === "power-saver" ? "balanced" : "performance")
                                                        Quickshell.execDetached(["powerprofilesctl", "set", next])
                                                        clockRoot.activeProfile = next
                                                        break
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // 4 & 5. CALENDAR CONTAINER
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 185
                            Layout.columnSpan: 2
                            radius: 18
                            color: clockRoot.pywalCardBg(5)
                            border.color: Colors.c(5)
                            border.width: 1.5

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 16
                                spacing: 16

                                ColumnLayout {
                                    spacing: 2
                                    Layout.alignment: Qt.AlignVCenter
                                    Text {
                                        text: clockRoot.timeString.split(":")[0]
                                        font.family: "Hack Nerd Font"
                                        font.pixelSize: 28
                                        font.bold: true
                                        color: Colors.c(5)
                                    }
                                    Text {
                                        text: clockRoot.timeString.split(":")[1]
                                        font.family: "Hack Nerd Font"
                                        font.pixelSize: 28
                                        font.bold: true
                                        color: Colors.c(5)
                                    }
                                    Text {
                                        text: clockRoot.dateString
                                        font.family: "Hack Nerd Font"
                                        font.pixelSize: 11
                                        color: Colors.c(8)
                                    }
                                }

                                Rectangle { implicitWidth: 1; Layout.fillHeight: true; color: Qt.rgba(1, 1, 1, 0.12) }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    spacing: 6

                                    RowLayout {
                                        Layout.fillWidth: true
                                        Text {
                                            text: clockRoot.viewDate.toLocaleDateString(Qt.locale(), "MMM yyyy")
                                            color: Colors.c(7)
                                            font.pixelSize: 12
                                            font.bold: true
                                            font.family: "Hack Nerd Font"
                                        }
                                        Item { Layout.fillWidth: true }
                                        Text {
                                            text: "󰅁"
                                            color: Colors.c(8)
                                            font.pixelSize: 14
                                            font.family: "Hack Nerd Font"
                                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: clockRoot.viewDate = new Date(clockRoot.viewDate.getFullYear(), clockRoot.viewDate.getMonth() - 1, 1) }
                                        }
                                        Text {
                                            text: "󰅂"
                                            color: Colors.c(8)
                                            font.pixelSize: 14
                                            font.family: "Hack Nerd Font"
                                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: clockRoot.viewDate = new Date(clockRoot.viewDate.getFullYear(), clockRoot.viewDate.getMonth() + 1, 1) }
                                        }
                                    }

                                    Repeater {
                                        model: 5
                                        RowLayout {
                                            Layout.fillWidth: true
                                            spacing: 0
                                            property var daysData: clockRoot.getCalendarDays(clockRoot.viewDate.getFullYear(), clockRoot.viewDate.getMonth())
                                            property var rowDays: daysData.slice(index * 7, (index + 1) * 7)

                                            Repeater {
                                                model: parent.rowDays
                                                Item {
                                                    Layout.fillWidth: true
                                                    implicitHeight: 20
                                                    Rectangle {
                                                        anchors.centerIn: parent
                                                        width: 18
                                                        height: 18
                                                        radius: 6
                                                        color: modelData.isToday ? Colors.c(1) : "transparent"
                                                        Text {
                                                            anchors.centerIn: parent
                                                            text: modelData.dayNumber
                                                            color: modelData.isToday ? Colors.c(0) : (modelData.isCurrentMonth ? Colors.c(7) : Colors.c(8))
                                                            font.pixelSize: 10
                                                            font.bold: modelData.isToday
                                                            font.family: "Hack Nerd Font"
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // 6. MEDIA WIDGET CARD (UPDATED: FILLS ENTIRE CARD SPACE)
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 185
                            radius: 18
                            color: clockRoot.pywalCardBg(3)
                            border.color: Colors.c(3)
                            border.width: 1.5

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 12
                                spacing: 4

                                RowLayout {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    spacing: 12

                                    Rectangle {
                                        Layout.fillHeight: true
                                        implicitWidth: height
                                        radius: 12
                                        color: Colors.bg()
                                        clip: true

                                        Image {
                                            id: artImg
                                            anchors.fill: parent
                                            source: clockRoot.player && clockRoot.player.trackArtUrl ? clockRoot.player.trackArtUrl : ""
                                            fillMode: Image.PreserveAspectCrop
                                            visible: source !== "" && status === Image.Ready
                                        }
                                        Text {
                                            anchors.centerIn: parent
                                            text: "󰝚"
                                            color: Colors.c(8)
                                            font.pixelSize: 28
                                            font.family: "Hack Nerd Font"
                                            visible: !artImg.visible
                                        }
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        spacing: 2

                                        Item { Layout.fillHeight: true }

                                        Text {
                                            Layout.fillWidth: true
                                            text: clockRoot.player ? (clockRoot.player.trackTitle || "No media") : "No media"
                                            color: Colors.c(7)
                                            font.bold: true
                                            font.pixelSize: 13
                                            font.family: "Hack Nerd Font"
                                            elide: Text.ElideRight
                                        }
                                        Text {
                                            Layout.fillWidth: true
                                            text: clockRoot.player ? (clockRoot.player.trackArtist || "") : ""
                                            color: Colors.c(8)
                                            font.pixelSize: 11
                                            font.family: "Hack Nerd Font"
                                            elide: Text.ElideRight
                                        }

                                        Item { Layout.fillHeight: true }

                                        RowLayout {
                                            spacing: 16
                                            visible: clockRoot.hasMedia
                                            Text {
                                                text: "󰒮"; color: Colors.c(7); font.pixelSize: 16; font.family: "Hack Nerd Font"
                                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: if (clockRoot.player) clockRoot.player.previous() }
                                            }
                                            Text {
                                                text: clockRoot.player && clockRoot.player.playbackState === MprisPlaybackState.Playing ? "󰏤" : "󰐊"
                                                color: Colors.c(1); font.pixelSize: 20; font.family: "Hack Nerd Font"
                                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: if (clockRoot.player) clockRoot.player.togglePlaying() }
                                            }
                                            Text {
                                                text: "󰒭"; color: Colors.c(7); font.pixelSize: 16; font.family: "Hack Nerd Font"
                                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: if (clockRoot.player) clockRoot.player.next() }
                                            }
                                        }

                                        Item { Layout.fillHeight: true }
                                    }
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 2
                                    visible: clockRoot.hasMedia

                                    Rectangle {
                                        Layout.fillWidth: true
                                        implicitHeight: 6
                                        radius: 3
                                        color: Colors.bg()

                                        Rectangle {
                                            width: (clockRoot.player && clockRoot.player.length > 0) ? parent.width * Math.min(1, Math.max(0, clockRoot.player.position / clockRoot.player.length)) : 0
                                            height: parent.height
                                            radius: 3
                                            color: Colors.c(3)
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: (mouse) => {
                                                if (clockRoot.player && clockRoot.player.length > 0) {
                                                    var pct = Math.max(0, Math.min(1, mouse.x / width))
                                                    clockRoot.player.position = pct * clockRoot.player.length
                                                }
                                            }
                                        }
                                    }

                                    RowLayout {
                                        Layout.fillWidth: true
                                        Text {
                                            text: clockRoot.player ? clockRoot.formatTime(clockRoot.player.position) : "0:00"
                                            color: Colors.c(8)
                                            font.pixelSize: 9
                                            font.family: "Hack Nerd Font"
                                        }
                                        Item { Layout.fillWidth: true }
                                        Text {
                                            text: clockRoot.player ? clockRoot.formatTime(clockRoot.player.length) : "0:00"
                                            color: Colors.c(8)
                                            font.pixelSize: 9
                                            font.family: "Hack Nerd Font"
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // DISPLAY MANAGEMENT & RESOLUTION SWITCHER
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: clockRoot.displayExpanded ? dispLayout.implicitHeight + 24 : 60
                        radius: 18
                        color: clockRoot.pywalCardBg(6)
                        border.color: Colors.c(6)
                        border.width: 1.5
                        clip: true

                        Behavior on implicitHeight { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

                        ColumnLayout {
                            id: dispLayout
                            anchors.top: parent.top
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.margins: 14
                            spacing: 12

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 12

                                Text { text: "󰍹"; color: Colors.c(6); font.pixelSize: 18; font.family: "Hack Nerd Font" }

                                ColumnLayout {
                                    spacing: 2
                                    Text { text: "Display Settings"; color: Colors.c(7); font.bold: true; font.pixelSize: 13; font.family: "Hack Nerd Font" }
                                    Text { text: "Active Monitor: " + clockRoot.selectedMonitor; color: Colors.c(8); font.pixelSize: 11; font.family: "Hack Nerd Font" }
                                }

                                Item { Layout.fillWidth: true }

                                Text {
                                    text: clockRoot.displayExpanded ? "󰅃" : "󰅀"
                                    color: Colors.c(7)
                                    font.pixelSize: 16
                                    font.family: "Hack Nerd Font"
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: clockRoot.displayExpanded = !clockRoot.displayExpanded
                                    }
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 10
                                visible: clockRoot.displayExpanded

                                Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Qt.rgba(1, 1, 1, 0.1) }

                                Text { text: "Resolution & Refresh Rate Presets"; color: Colors.c(7); font.bold: true; font.pixelSize: 12; font.family: "Hack Nerd Font" }

                                Flow {
                                    Layout.fillWidth: true
                                    spacing: 8

                                    Repeater {
                                        model: clockRoot.resolutionPresets
                                        delegate: Rectangle {
                                            implicitWidth: resText.implicitWidth + 20
                                            implicitHeight: 30
                                            radius: 8
                                            color: resArea.containsMouse ? Colors.c(6) : Colors.bg()
                                            border.color: Colors.c(6)
                                            border.width: 1

                                            Text {
                                                id: resText
                                                anchors.centerIn: parent
                                                text: modelData.label
                                                color: resArea.containsMouse ? Colors.c(0) : Colors.c(7)
                                                font.pixelSize: 11
                                                font.bold: true
                                                font.family: "Hack Nerd Font"
                                            }

                                            MouseArea {
                                                id: resArea
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: clockRoot.applyResolution(clockRoot.selectedMonitor, modelData.w, modelData.h, modelData.r || 60)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // SYSTEM UPDATES CARD
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 70
                        radius: 18
                        color: clockRoot.pywalCardBg(4)
                        border.color: Colors.c(4)
                        border.width: 1.5

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 14
                            spacing: 12

                            Text { text: "󰏔"; color: Colors.c(4); font.pixelSize: 22; font.family: "Hack Nerd Font" }

                            ColumnLayout {
                                spacing: 2
                                Text { text: "System Updates"; color: Colors.c(7); font.bold: true; font.pixelSize: 13; font.family: "Hack Nerd Font" }
                                Text {
                                    text: clockRoot.updateCount > 0 ? (clockRoot.pacmanCount + " Pacman, " + clockRoot.aurCount + " AUR pending") : "System up to date"
                                    color: Colors.c(8)
                                    font.pixelSize: 11
                                    font.family: "Hack Nerd Font"
                                }
                            }

                            Item { Layout.fillWidth: true }

                            Rectangle {
                                implicitWidth: updateBtnText.implicitWidth + 20
                                implicitHeight: 32
                                radius: 8
                                color: Colors.c(4)

                                Text {
                                    id: updateBtnText
                                    anchors.centerIn: parent
                                    text: "Upgrade System"
                                    color: Colors.c(0)
                                    font.pixelSize: 11
                                    font.bold: true
                                    font.family: "Hack Nerd Font"
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: upgradeProc.running = true
                                }
                            }
                        }
                    }

                    // SLIDERS: VOLUME & BRIGHTNESS
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 14

                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: 44
                            radius: 14
                            color: clockRoot.pywalCardBg(1)
                            border.color: Colors.c(1)
                            border.width: 1.5

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 14
                                anchors.rightMargin: 14
                                spacing: 10

                                Text {
                                    text: clockRoot.sink && clockRoot.sink.audio && clockRoot.sink.audio.muted ? "󰝟" : "󰕾"
                                    color: Colors.c(7)
                                    font.pixelSize: 16
                                    font.family: "Hack Nerd Font"
                                }

                                Rectangle {
                                    Layout.fillWidth: true
                                    implicitHeight: 8
                                    radius: 4
                                    color: Colors.bg()

                                    Rectangle {
                                        width: parent.width * (clockRoot.sink && clockRoot.sink.audio ? clockRoot.sink.audio.volume : 0)
                                        height: parent.height
                                        radius: 4
                                        color: Colors.c(1)
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onPositionChanged: (mouse) => {
                                            if (pressed && clockRoot.sink && clockRoot.sink.audio) {
                                                clockRoot.sink.audio.volume = Math.max(0, Math.min(1, mouse.x / width))
                                            }
                                        }
                                        onPressed: (mouse) => {
                                            if (clockRoot.sink && clockRoot.sink.audio) {
                                                clockRoot.sink.audio.volume = Math.max(0, Math.min(1, mouse.x / width))
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: 44
                            radius: 14
                            color: clockRoot.pywalCardBg(3)
                            border.color: Colors.c(3)
                            border.width: 1.5

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 14
                                anchors.rightMargin: 14
                                spacing: 10

                                Text {
                                    text: "󰃟"
                                    color: Colors.c(7)
                                    font.pixelSize: 16
                                    font.family: "Hack Nerd Font"
                                }

                                Rectangle {
                                    Layout.fillWidth: true
                                    implicitHeight: 8
                                    radius: 4
                                    color: Colors.bg()

                                    Rectangle {
                                        width: parent.width * (clockRoot.brightnessLevel / 100)
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
                                                clockRoot.brightnessLevel = v
                                                setBrightnessProcess.setLevel(v)
                                            }
                                        }
                                        onPressed: (mouse) => {
                                            var v = Math.max(5, Math.min(100, Math.round((mouse.x / width) * 100)))
                                            clockRoot.brightnessLevel = v
                                            setBrightnessProcess.setLevel(v)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // ================================================
                // TAB 2: MEDIA VIEW
                // ================================================
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 320
                    radius: 18
                    color: clockRoot.pywalCardBg(1)
                    border.color: Colors.c(1)
                    border.width: 1.5
                    visible: clockRoot.activeTab === "Media"

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 20
                        spacing: 16

                        Rectangle {
                            Layout.alignment: Qt.AlignHCenter
                            implicitWidth: 90
                            implicitHeight: 90
                            radius: 18
                            color: Colors.bg()
                            clip: true

                            Image {
                                anchors.fill: parent
                                source: clockRoot.player && clockRoot.player.trackArtUrl ? clockRoot.player.trackArtUrl : ""
                                fillMode: Image.PreserveAspectCrop
                                visible: source !== "" && status === Image.Ready
                            }
                            Text {
                                anchors.centerIn: parent
                                text: "󰝚"
                                color: Colors.c(8)
                                font.pixelSize: 36
                                font.family: "Hack Nerd Font"
                                visible: !parent.children[0].visible
                            }
                        }

                        ColumnLayout {
                            spacing: 4
                            Text {
                                text: clockRoot.player ? (clockRoot.player.trackTitle || "No Active Media") : "No Active Media"
                                color: Colors.c(7)
                                font.bold: true
                                font.pixelSize: 18
                                font.family: "Hack Nerd Font"
                                Layout.alignment: Qt.AlignHCenter
                            }
                            Text {
                                text: clockRoot.player ? (clockRoot.player.trackArtist || "Unknown Artist") : "--"
                                color: Colors.c(8)
                                font.pixelSize: 14
                                font.family: "Hack Nerd Font"
                                Layout.alignment: Qt.AlignHCenter
                            }
                        }

                        // Song Seek Slider
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 4
                            visible: clockRoot.hasMedia

                            Rectangle {
                                Layout.fillWidth: true
                                implicitHeight: 8
                                radius: 4
                                color: Colors.bg()

                                Rectangle {
                                    width: (clockRoot.player && clockRoot.player.length > 0) ? parent.width * Math.min(1, Math.max(0, clockRoot.player.position / clockRoot.player.length)) : 0
                                    height: parent.height
                                    radius: 4
                                    color: Colors.c(1)
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: (mouse) => {
                                        if (clockRoot.player && clockRoot.player.length > 0) {
                                            var pct = Math.max(0, Math.min(1, mouse.x / width))
                                            clockRoot.player.position = pct * clockRoot.player.length
                                        }
                                    }
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                Text {
                                    text: clockRoot.player ? clockRoot.formatTime(clockRoot.player.position) : "0:00"
                                    color: Colors.c(8)
                                    font.pixelSize: 11
                                    font.family: "Hack Nerd Font"
                                }
                                Item { Layout.fillWidth: true }
                                Text {
                                    text: clockRoot.player ? clockRoot.formatTime(clockRoot.player.length) : "0:00"
                                    color: Colors.c(8)
                                    font.pixelSize: 11
                                    font.family: "Hack Nerd Font"
                                }
                            }
                        }

                        RowLayout {
                            spacing: 24
                            Layout.alignment: Qt.AlignHCenter
                            Text {
                                text: "󰒮"; color: Colors.c(7); font.pixelSize: 22; font.family: "Hack Nerd Font"
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: if (clockRoot.player) clockRoot.player.previous() }
                            }
                            Text {
                                text: clockRoot.player && clockRoot.player.playbackState === MprisPlaybackState.Playing ? "󰏤" : "󰐊"
                                color: Colors.c(1); font.pixelSize: 28; font.family: "Hack Nerd Font"
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: if (clockRoot.player) clockRoot.player.togglePlaying() }
                            }
                            Text {
                                text: "󰒭"; color: Colors.c(7); font.pixelSize: 22; font.family: "Hack Nerd Font"
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: if (clockRoot.player) clockRoot.player.next() }
                            }
                        }
                    }
                }

                // ================================================
                // TAB 3: NETWORK & BLUETOOTH COMBINED VIEW
                // ================================================
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 14
                    visible: clockRoot.activeTab === "Network/BT"

                    // Network Panel
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: comboNetLayout.implicitHeight + 28
                        radius: 18
                        color: clockRoot.pywalCardBg(2)
                        border.color: Colors.c(2)
                        border.width: 1.5

                        ColumnLayout {
                            id: comboNetLayout
                            anchors.top: parent.top
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.margins: 14
                            spacing: 12

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 10

                                Text {
                                    text: clockRoot.connectionType === "wifi" ? "󰤨" : (clockRoot.connectionType === "ethernet" ? "󰈀" : "󰤭")
                                    color: Colors.c(2)
                                    font.pixelSize: 18
                                    font.family: "Hack Nerd Font"
                                }

                                ColumnLayout {
                                    spacing: 2
                                    Text {
                                        text: clockRoot.activeName
                                        color: Colors.c(7)
                                        font.bold: true
                                        font.pixelSize: 13
                                        font.family: "Hack Nerd Font"
                                    }
                                    Text {
                                        text: clockRoot.subStatus + " (" + clockRoot.ipAddress + ")"
                                        color: Colors.c(8)
                                        font.pixelSize: 10
                                        font.family: "Hack Nerd Font"
                                    }
                                }

                                Item { Layout.fillWidth: true }
                            }

                            Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Qt.rgba(1, 1, 1, 0.1) }

                            RowLayout {
                                Layout.fillWidth: true
                                Text { text: "Gateway: " + clockRoot.gateway; color: Colors.c(8); font.pixelSize: 10; font.family: "Hack Nerd Font" }
                                Item { Layout.fillWidth: true }
                                Text { text: "Ping: " + clockRoot.pingMs; color: Colors.c(8); font.pixelSize: 10; font.family: "Hack Nerd Font" }
                            }

                            RowLayout {
                                spacing: 6
                                Text { text: "DNS:"; color: Colors.c(8); font.pixelSize: 10; font.family: "Hack Nerd Font" }
                                Repeater {
                                    model: ["DHCP", "Cloudflare", "Google"]
                                    delegate: Rectangle {
                                        implicitWidth: comboDnsText.implicitWidth + 10
                                        implicitHeight: 18
                                        radius: 9
                                        color: clockRoot.selectedDns === modelData ? Colors.c(2) : Colors.bg()
                                        Text {
                                            id: comboDnsText
                                            anchors.centerIn: parent
                                            text: modelData
                                            color: clockRoot.selectedDns === modelData ? Colors.c(0) : Colors.c(7)
                                            font.pixelSize: 9
                                            font.family: "Hack Nerd Font"
                                        }
                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: clockRoot.applyDns(modelData)
                                        }
                                    }
                                }
                            }

                            Text {
                                text: "Available Wi-Fi Networks"
                                color: Colors.c(7)
                                font.bold: true
                                font.pixelSize: 12
                                font.family: "Hack Nerd Font"
                                visible: clockRoot.wifiEnabled
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 4
                                visible: clockRoot.wifiEnabled

                                Repeater {
                                    model: clockRoot.otherNetworks.slice(0, 4)
                                    delegate: Rectangle {
                                        Layout.fillWidth: true
                                        implicitHeight: 28
                                        radius: 6
                                        color: comboNetArea.containsMouse ? Qt.rgba(1, 1, 1, 0.05) : "transparent"

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.leftMargin: 6
                                            anchors.rightMargin: 6

                                            Text { text: "󰤨"; color: Colors.c(7); font.pixelSize: 12; font.family: "Hack Nerd Font" }
                                            Text { text: modelData; color: Colors.c(7); font.pixelSize: 11; font.family: "Hack Nerd Font"; elide: Text.ElideRight; Layout.fillWidth: true }
                                            Text { text: "Connect"; color: Colors.c(2); font.pixelSize: 10; font.bold: true; font.family: "Hack Nerd Font" }
                                        }

                                        MouseArea {
                                            id: comboNetArea
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: clockRoot.connectWifi(modelData)
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Bluetooth Panel
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: comboBtLayout.implicitHeight + 28
                        radius: 18
                        color: clockRoot.pywalCardBg(5)
                        border.color: Colors.c(5)
                        border.width: 1.5

                        ColumnLayout {
                            id: comboBtLayout
                            anchors.top: parent.top
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.margins: 14
                            spacing: 12

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 10

                                Text { text: "󰂯"; color: Colors.c(5); font.pixelSize: 18; font.family: "Hack Nerd Font" }

                                ColumnLayout {
                                    spacing: 2
                                    Text { text: "Bluetooth"; color: Colors.c(7); font.bold: true; font.pixelSize: 13; font.family: "Hack Nerd Font" }
                                    Text { text: clockRoot.btPowered ? (clockRoot.connectedDevices.length + " Connected") : "Disabled"; color: Colors.c(8); font.pixelSize: 10; font.family: "Hack Nerd Font" }
                                }

                                Item { Layout.fillWidth: true }
                            }

                            Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Qt.rgba(1, 1, 1, 0.1) }

                            Text { text: "Connected Devices"; color: Colors.c(7); font.bold: true; font.pixelSize: 11; font.family: "Hack Nerd Font" }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 4
                                visible: clockRoot.connectedDevices.length > 0
                                Repeater {
                                    model: clockRoot.connectedDevices
                                    delegate: Rectangle {
                                        Layout.fillWidth: true
                                        implicitHeight: 28
                                        radius: 6
                                        color: Qt.rgba(1, 1, 1, 0.05)
                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.leftMargin: 6
                                            anchors.rightMargin: 6
                                            Text { text: "󰂱"; color: Colors.c(5); font.pixelSize: 12; font.family: "Hack Nerd Font" }
                                            Text { text: modelData.name || modelData.mac; color: Colors.c(7); font.pixelSize: 11; font.family: "Hack Nerd Font"; elide: Text.ElideRight; Layout.fillWidth: true }
                                            Text { text: "Disconnect"; color: Colors.c(1); font.pixelSize: 10; font.bold: true; font.family: "Hack Nerd Font" }
                                        }
                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: Quickshell.execDetached(["bluetoothctl", "disconnect", modelData.mac])
                                        }
                                    }
                                }
                            }

                            Text {
                                visible: clockRoot.connectedDevices.length === 0
                                text: "No devices connected"
                                color: Colors.c(8)
                                font.pixelSize: 10
                                font.family: "Hack Nerd Font"
                            }

                            Text { text: "Available Devices"; color: Colors.c(7); font.bold: true; font.pixelSize: 11; font.family: "Hack Nerd Font" }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 4
                                Repeater {
                                    model: clockRoot.availableDevices.slice(0, 4)
                                    delegate: Rectangle {
                                        Layout.fillWidth: true
                                        implicitHeight: 28
                                        radius: 6
                                        color: comboBtArea.containsMouse ? Qt.rgba(1, 1, 1, 0.05) : "transparent"
                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.leftMargin: 6
                                            anchors.rightMargin: 6
                                            Text { text: "󰂯"; color: Colors.c(7); font.pixelSize: 12; font.family: "Hack Nerd Font" }
                                            Text { text: modelData.name || modelData.mac; color: Colors.c(7); font.pixelSize: 11; font.family: "Hack Nerd Font"; elide: Text.ElideRight; Layout.fillWidth: true }
                                            Text { text: "Pair"; color: Colors.c(5); font.pixelSize: 10; font.bold: true; font.family: "Hack Nerd Font" }
                                        }
                                        MouseArea {
                                            id: comboBtArea
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: Quickshell.execDetached(["bluetoothctl", "connect", modelData.mac])
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // ================================================
                // TAB 4: PERFORMANCE VIEW
                // ================================================
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 14
                    visible: clockRoot.activeTab === "Performance"

                    GridLayout {
                        Layout.fillWidth: true
                        columns: 3
                        rowSpacing: 14
                        columnSpacing: 14

                        Repeater {
                            model: [
                                { label: "CPU Usage", val: clockRoot.cpuUsage + "%", sub: "Processor Load", icon: "󰍛", colorIdx: 1 },
                                { label: "Memory", val: clockRoot.memUsage + "%", sub: clockRoot.memText, icon: "󰘚", colorIdx: 2 },
                                { label: "Storage", val: clockRoot.diskUsage + "%", sub: clockRoot.diskText, icon: "󰋊", colorIdx: 3 }
                            ]
                            delegate: Rectangle {
                                Layout.fillWidth: true
                                implicitHeight: 140
                                radius: 18
                                color: clockRoot.pywalCardBg(modelData.colorIdx)
                                border.color: Colors.c(modelData.colorIdx)
                                border.width: 1.5

                                ColumnLayout {
                                    anchors.centerIn: parent
                                    spacing: 6
                                    Text { text: modelData.icon; color: Colors.c(modelData.colorIdx); font.pixelSize: 24; font.family: "Hack Nerd Font"; Layout.alignment: Qt.AlignHCenter }
                                    Text { text: modelData.label; color: Colors.c(8); font.pixelSize: 12; font.family: "Hack Nerd Font"; Layout.alignment: Qt.AlignHCenter }
                                    Text { text: modelData.val; color: Colors.c(7); font.pixelSize: 22; font.bold: true; font.family: "Hack Nerd Font"; Layout.alignment: Qt.AlignHCenter }
                                    Text { text: modelData.sub; color: Colors.c(8); font.pixelSize: 11; font.family: "Hack Nerd Font"; Layout.alignment: Qt.AlignHCenter }
                                }
                            }
                        }
                    }

                    // BATTERY HEALTH & POWER DETAILS CARD
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 110
                        radius: 18
                        color: clockRoot.pywalCardBg(5)
                        border.color: Colors.c(5)
                        border.width: 1.5
                        visible: clockRoot.hasBattery

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 14
                            spacing: 8

                            RowLayout {
                                Layout.fillWidth: true
                                Text { text: "󰁹 Battery & Power Health"; color: Colors.c(7); font.bold: true; font.pixelSize: 13; font.family: "Hack Nerd Font" }
                                Item { Layout.fillWidth: true }
                                Text { text: clockRoot.battPct + "% " + (clockRoot.charging ? "(Charging)" : "(Discharging)"); color: Colors.c(5); font.bold: true; font.pixelSize: 12; font.family: "Hack Nerd Font" }
                            }

                            Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Qt.rgba(1, 1, 1, 0.1) }

                            GridLayout {
                                Layout.fillWidth: true
                                columns: 4
                                rowSpacing: 4
                                columnSpacing: 12

                                Text { text: "Time Left: " + clockRoot.timeLeft; color: Colors.c(8); font.pixelSize: 11; font.family: "Hack Nerd Font" }
                                Text { text: "Draw Rate: " + clockRoot.wattage; color: Colors.c(8); font.pixelSize: 11; font.family: "Hack Nerd Font" }
                                Text { text: "Cycles: " + clockRoot.chargeCycles; color: Colors.c(8); font.pixelSize: 11; font.family: "Hack Nerd Font" }
                                Text { text: "Capacity: " + clockRoot.batterySize; color: Colors.c(8); font.pixelSize: 11; font.family: "Hack Nerd Font" }
                            }
                        }
                    }
                }

                // ================================================
                // TAB 5: WEATHER DETAILS VIEW
                // ================================================
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 270
                    radius: 18
                    color: clockRoot.pywalCardBg(4)
                    border.color: Colors.c(4)
                    border.width: 1.5
                    visible: clockRoot.activeTab === "Weather"

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 20
                        spacing: 16

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 10

                            TextField {
                                id: locationInput
                                Layout.fillWidth: true
                                implicitHeight: 36
                                placeholderText: "Enter city or location..."
                                text: clockRoot.customLocation
                                font.pixelSize: 13
                                font.family: "Hack Nerd Font"
                                color: Colors.c(7)
                                background: Rectangle {
                                    color: Colors.bg()
                                    radius: 10
                                    border.color: locationInput.activeFocus ? Colors.c(4) : Colors.c(8)
                                    border.width: 1
                                }
                                onAccepted: {
                                    if (text.trim() !== "") {
                                        clockRoot.customLocation = text.trim()
                                        clockRoot.refreshWeather()
                                    }
                                }
                            }

                            Rectangle {
                                implicitWidth: updateLocText.implicitWidth + 20
                                implicitHeight: 36
                                radius: 10
                                color: Colors.c(4)

                                Text {
                                    id: updateLocText
                                    anchors.centerIn: parent
                                    text: "Update"
                                    color: Colors.c(0)
                                    font.bold: true
                                    font.pixelSize: 12
                                    font.family: "Hack Nerd Font"
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (locationInput.text.trim() !== "") {
                                            clockRoot.customLocation = locationInput.text.trim()
                                            clockRoot.refreshWeather()
                                        }
                                    }
                                }
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 24

                            ColumnLayout {
                                spacing: 6
                                Text { text: clockRoot.iconSymbol; font.pixelSize: 48; color: Colors.c(1); font.family: "Hack Nerd Font" }
                                Text { text: clockRoot.currentTemp; font.pixelSize: 28; font.bold: true; color: Colors.c(7); font.family: "Hack Nerd Font" }
                                Text { text: clockRoot.condition; font.pixelSize: 14; color: Colors.c(4); font.family: "Hack Nerd Font" }
                                Text { text: clockRoot.location; font.pixelSize: 12; color: Colors.c(8); font.family: "Hack Nerd Font" }
                            }

                            Item { Layout.fillWidth: true }

                            ColumnLayout {
                                spacing: 12
                                Repeater {
                                    model: [
                                        { name: "High / Low", val: clockRoot.tempHigh + " / " + clockRoot.tempLow },
                                        { name: "Humidity", val: clockRoot.humidity },
                                        { name: "Wind Speed", val: clockRoot.windSpeed }
                                    ]
                                    delegate: RowLayout {
                                        spacing: 16
                                        Text { text: modelData.name; color: Colors.c(8); font.pixelSize: 13; font.family: "Hack Nerd Font" }
                                        Item { Layout.fillWidth: true }
                                        Text { text: modelData.val; color: Colors.c(7); font.bold: true; font.pixelSize: 14; font.family: "Hack Nerd Font" }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // ============================================================
    // WALLPAPER PICKER
    // ============================================================
    PopupWindow {
        id: wallpaperPickerPopup
        visible: false
        anchor.window: bar
        anchor.rect.x: (bar.width - wallpaperPickerPopup.implicitWidth) / 2
        anchor.rect.y: (bar.screen.height - wallpaperPickerPopup.implicitHeight) / 2

        grabFocus: true
        implicitWidth: 920
        implicitHeight: 640
        color: "transparent"

        onVisibleChanged: {
            if (visible) clockRoot.rescanWallpapers()
        }

        Rectangle {
            anchors.fill: parent
            radius: 20
            color: Colors.bg()
            border.color: Colors.c(1)
            border.width: 1.5

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 22
                spacing: 16

                RowLayout {
                    Layout.fillWidth: true

                    Text {
                        text: "Wallpaper picker"
                        color: Colors.c(7)
                        font.pixelSize: 20
                        font.bold: true
                        font.family: "Hack Nerd Font"
                    }

                    Item { Layout.fillWidth: true }

                    Rectangle {
                        implicitWidth: randomRow.implicitWidth + 24
                        implicitHeight: 34
                        radius: 10
                        color: Colors.c(1)

                        RowLayout {
                            id: randomRow
                            anchors.centerIn: parent
                            spacing: 8

                            Text { text: "󰑐"; color: Colors.c(0); font.pixelSize: 16; font.family: "Hack Nerd Font" }
                            Text { text: "Random"; color: Colors.c(0); font.pixelSize: 14; font.bold: true; font.family: "Hack Nerd Font" }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: clockRoot.setRandomWallpaper()
                        }
                    }
                }

                Text {
                    visible: clockRoot.wallpaperList.length === 0
                    text: "No images found in your Wallpapers folder"
                    color: Colors.c(8)
                    font.pixelSize: 14
                    font.family: "Hack Nerd Font"
                    Layout.alignment: Qt.AlignCenter
                }

                GridView {
                    id: grid
                    visible: clockRoot.wallpaperList.length > 0
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    property int columns: Math.max(3, Math.floor(width / 260))
                    cellWidth: width / columns
                    cellHeight: cellWidth * 0.65

                    model: clockRoot.wallpaperList
                    delegate: Item {
                        width: grid.cellWidth
                        height: grid.cellHeight

                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: 6
                            radius: 10
                            color: Colors.c(0)
                            border.color: clockRoot.currentWallpaper === modelData ? Colors.c(1) : Colors.c(8)
                            border.width: clockRoot.currentWallpaper === modelData ? 3 : 1
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
                                onClicked: clockRoot.applyWallpaper(modelData)
                            }
                        }
                    }
                }
            }
        }
    }

    // ============================================================
    // SCREENSHOT MENU
    // ============================================================
    PopupWindow {
        id: screenshotMenuPopup
        visible: false
        anchor.window: bar
        anchor.rect.x: bar.width - screenshotMenuPopup.implicitWidth
        anchor.rect.y: bar.implicitHeight + 12
        grabFocus: true
        implicitWidth: 280
        implicitHeight: 290
        color: "transparent"

        Rectangle {
            anchors.fill: parent
            radius: 18
            color: Colors.bg()
            border.color: Colors.c(1)
            border.width: 1.5

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 20
                spacing: 14

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    Text { text: "󰄄"; color: Colors.c(1); font.pixelSize: 22; font.family: "Hack Nerd Font" }
                    Text { text: "Screenshot"; color: Colors.c(7); font.bold: true; font.pixelSize: 16; font.family: "Hack Nerd Font" }
                }

                Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Colors.c(8) }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Repeater {
                        model: [
                            { key: "region", icon: "󰆞", label: "Select region" },
                            { key: "window", icon: "󰖯", label: "Active window" },
                            { key: "full", icon: "󰹑", label: "Full screen" },
                            { key: "delayed", icon: "󰥔", label: "Full screen (3s delay)" }
                        ]
                        delegate: Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: 42
                            radius: 10
                            color: rowArea.containsMouse ? clockRoot.pywalCardBg(1) : "transparent"

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 12
                                spacing: 12

                                Text { text: modelData.icon; color: Colors.c(1); font.pixelSize: 16; font.family: "Hack Nerd Font" }
                                Text { text: modelData.label; color: Colors.c(7); font.pixelSize: 13; font.family: "Hack Nerd Font" }
                                Item { Layout.fillWidth: true }
                            }

                            MouseArea {
                                id: rowArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (modelData.key === "delayed") clockRoot.shootScreenshotDelayed()
                                    else clockRoot.shootScreenshot(modelData.key)
                                }
                            }
                        }
                    }
                }

                Item { Layout.fillHeight: true }

                Text {
                    text: "Saved to ~/Pictures/Screenshots"
                    color: Colors.c(8)
                    font.pixelSize: 10
                    font.family: "Hack Nerd Font"
                }
            }
        }
    }
}
