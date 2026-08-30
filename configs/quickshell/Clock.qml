import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

Item {
    id: clockRoot

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

    implicitWidth: pillLayout.implicitWidth + 14
    implicitHeight: 24

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

    Rectangle {
        id: mainPill
        anchors.verticalCenter: parent.verticalCenter
        implicitWidth: pillLayout.implicitWidth + 14
        implicitHeight: 24
        radius: 12
        color: Colors.c(1)

        RowLayout {
            id: pillLayout
            anchors.centerIn: parent
            spacing: 8

            Text {
                text: clockRoot.iconSymbol
                color: Colors.c(0)
                font.pixelSize: 13
                font.family: "Hack Nerd Font"
            }
            Text {
                text: clockRoot.currentTemp
                color: Colors.c(0)
                font.pixelSize: 12
                font.bold: true
                font.family: "Hack Nerd Font"
            }

            Rectangle {
                implicitWidth: 1
                implicitHeight: 12
                color: Qt.tint(Colors.c(0), Qt.rgba(0, 0, 0, 0.4))
            }

            Text {
                text: clockRoot.timeString + "  " + clockRoot.dateString
                color: Colors.c(0)
                font.pixelSize: 12
                font.bold: true
                font.family: "Hack Nerd Font"
            }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                clockRoot.viewDate = new Date()
                bar.togglePopup(combinedPopup)
            }
        }
    }

    PopupWindow {
        id: combinedPopup
        visible: false
        anchor.item: clockRoot
        anchor.rect.x: (clockRoot.implicitWidth - combinedPopup.implicitWidth) / 2
        anchor.rect.y: clockRoot.height + 8

        grabFocus: true

        implicitWidth: 500
        implicitHeight: 250
        color: "transparent"

        onVisibleChanged: {
            if (visible) {
                locationInput.forceActiveFocus()
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

            RowLayout {
                anchors.fill: parent
                anchors.margins: 14
                spacing: 14

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 8

                    RowLayout {
                        Layout.fillWidth: true

                        Text {
                            text: clockRoot.viewDate.toLocaleDateString(Qt.locale(), "MMMM yyyy")
                            color: Colors.c(7)
                            font.pixelSize: 14
                            font.bold: true
                            font.family: "Hack Nerd Font"
                        }

                        Item { Layout.fillWidth: true }

                        Text {
                            text: "󰅁"
                            color: Colors.c(8)
                            font.pixelSize: 16
                            font.family: "Hack Nerd Font"

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: clockRoot.viewDate = new Date(clockRoot.viewDate.getFullYear(), clockRoot.viewDate.getMonth() - 1, 1)
                            }
                        }

                        Text {
                            text: "󰅂"
                            color: Colors.c(8)
                            font.pixelSize: 16
                            font.family: "Hack Nerd Font"

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: clockRoot.viewDate = new Date(clockRoot.viewDate.getFullYear(), clockRoot.viewDate.getMonth() + 1, 1)
                            }
                        }
                    }

                    Repeater {
                        model: 6

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 0

                            property var daysData: clockRoot.getCalendarDays(clockRoot.viewDate.getFullYear(), clockRoot.viewDate.getMonth())
                            property var rowDays: daysData.slice(index * 7, (index + 1) * 7)

                            Repeater {
                                model: parent.rowDays

                                Item {
                                    Layout.fillWidth: true
                                    implicitHeight: 22

                                    Rectangle {
                                        anchors.centerIn: parent
                                        width: 20
                                        height: 20
                                        radius: 4
                                        color: modelData.isToday ? Colors.c(1) : "transparent"

                                        Text {
                                            anchors.centerIn: parent
                                            text: modelData.dayNumber
                                            color: modelData.isToday ? Colors.c(0)
                                                                     : (modelData.isCurrentMonth ? Colors.c(7) : Colors.c(8))
                                            font.pixelSize: 11
                                            font.bold: modelData.isToday
                                            font.family: "Hack Nerd Font"
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.fillHeight: true
                    implicitWidth: 1
                    color: Colors.c(8)
                    opacity: 0.3
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 8

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 28
                        radius: 6
                        color: Colors.c(0)
                        border.color: locationInput.activeFocus ? Colors.c(1) : Colors.c(8)
                        border.width: 1

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.IBeamCursor
                            onClicked: locationInput.forceActiveFocus()
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            spacing: 6

                            Text {
                                text: "󰍉"
                                color: locationInput.activeFocus ? Colors.c(1) : Colors.c(8)
                                font.pixelSize: 13
                                font.family: "Hack Nerd Font"
                            }

                            TextInput {
                                id: locationInput
                                Layout.fillWidth: true
                                text: clockRoot.customLocation
                                color: Colors.c(7)
                                font.pixelSize: 12
                                font.bold: true
                                font.family: "Hack Nerd Font"
                                clip: true
                                focus: true

                                onAccepted: {
                                    if (text.trim() !== "") {
                                        clockRoot.customLocation = text.trim()
                                        clockRoot.refreshWeather()
                                    }
                                }
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        ColumnLayout {
                            spacing: 2
                            Layout.fillWidth: true

                            Text {
                                text: clockRoot.location
                                color: Colors.c(7)
                                font.bold: true
                                font.pixelSize: 18
                                font.family: "Hack Nerd Font"
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                            Text {
                                text: clockRoot.condition
                                color: Colors.c(8)
                                font.pixelSize: 12
                                font.family: "Hack Nerd Font"
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                        }

                        Text {
                            text: clockRoot.iconSymbol
                            color: Colors.c(1)
                            font.pixelSize: 42
                            font.family: "Hack Nerd Font"
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true

                        Text {
                            text: clockRoot.currentTemp
                            color: Colors.c(7)
                            font.bold: true
                            font.pixelSize: 30
                            font.family: "Hack Nerd Font"
                            Layout.alignment: Qt.AlignVCenter
                        }

                        Item { Layout.fillWidth: true }

                        ColumnLayout {
                            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                            spacing: 2

                            RowLayout {
                                spacing: 4
                                Text {
                                    text: "󰄝"
                                    color: Colors.c(1)
                                    font.pixelSize: 12
                                    font.family: "Hack Nerd Font"
                                }
                                Text {
                                    text: clockRoot.tempHigh
                                    color: Colors.c(7)
                                    font.pixelSize: 12
                                    font.bold: true
                                    font.family: "Hack Nerd Font"
                                }
                            }

                            RowLayout {
                                spacing: 4
                                Text {
                                    text: "󰄼"
                                    color: Colors.c(4)
                                    font.pixelSize: 12
                                    font.family: "Hack Nerd Font"
                                }
                                Text {
                                    text: clockRoot.tempLow
                                    color: Colors.c(7)
                                    font.pixelSize: 12
                                    font.bold: true
                                    font.family: "Hack Nerd Font"
                                }
                            }
                        }
                    }

                    Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Colors.c(8); opacity: 0.25 }

                    RowLayout {
                        Layout.fillWidth: true

                        RowLayout {
                            spacing: 6
                            Text {
                                text: "󰖎"
                                color: Colors.c(1)
                                font.pixelSize: 14
                                font.family: "Hack Nerd Font"
                            }
                            ColumnLayout {
                                spacing: 0
                                Text {
                                    text: "Humidity"
                                    color: Colors.c(8)
                                    font.pixelSize: 9
                                    font.family: "Hack Nerd Font"
                                }
                                Text {
                                    text: clockRoot.humidity
                                    color: Colors.c(7)
                                    font.pixelSize: 11
                                    font.bold: true
                                    font.family: "Hack Nerd Font"
                                }
                            }
                        }

                        Item { Layout.fillWidth: true }

                        RowLayout {
                            spacing: 6
                            Text {
                                text: "󰈐"
                                color: Colors.c(1)
                                font.pixelSize: 14
                                font.family: "Hack Nerd Font"
                            }
                            ColumnLayout {
                                spacing: 0
                                Text {
                                    text: "Wind Speed"
                                    color: Colors.c(8)
                                    font.pixelSize: 9
                                    font.family: "Hack Nerd Font"
                                }
                                Text {
                                    text: clockRoot.windSpeed
                                    color: Colors.c(7)
                                    font.pixelSize: 11
                                    font.bold: true
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
