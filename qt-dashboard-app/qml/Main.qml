import QtQuick
import QtQuick.Window
import QtQuick.Layouts

Window {
    id: root
    visibility: Window.FullScreen
    flags: Qt.FramelessWindowHint
    width: Screen.width
    height: Screen.height
    visible: true
    color: bgColor
    title: "Environment Monitoring"

    // ---------- Theme (Editorial palette) ----------
    readonly property bool  isDark: sensorBackend.nightMode === 1

    readonly property color bgColor:   isDark ? "#16150F" : "#F3EFE6"   // warm paper / warm charcoal
    readonly property color inkColor:  isDark ? "#F1EDE2" : "#191814"   // primary ink
    readonly property color accent:    isDark ? "#F0563A" : "#DC4226"   // vermillion signature
    readonly property color mutedColor:isDark ? "#857F6E" : "#A39C8C"   // labels / date
    readonly property color hairColor: isDark ? "#34312A" : "#CFC8B8"   // rules & dividers
    readonly property color unitColor: isDark ? "#7C776A" : "#8C8678"   // units
    readonly property color statColor: isDark ? "#9A9381" : "#7D7768"   // status line

    Behavior on color { ColorAnimation { duration: 400 } }

    // ---------- Fonts ----------
    // A Helvetica-class grotesk carries the editorial look. Set this to
    // "Helvetica Neue" / "Arial" / "Inter" if available on the BeagleBone;
    // falls back to the app default (DejaVu Sans) otherwise.
    readonly property string fontFamily: "Inter, Arial, Helvetica, DejaVu Sans, sans-serif"

    // ---------- Clock options ----------
    property bool use24h: true

    // ===================== Helpers (unchanged) =====================
    function parseNumber(str) {
        if (!str || str === "--") return 0.0;
        var num = parseFloat(str.replace(/[^0-9.-]/g, ""));
        return isNaN(num) ? 0.0 : num;
    }

    // We split values like "30.4 °C" into value ("30.4") and unit ("°C")
    // so we can style the number huge and the unit smaller.
    function splitValueAndUnit(str, defaultUnit) {
        if (!str || str === "--") return { value: "--", unit: defaultUnit };
        var match = str.match(/^([0-9.-]+)\s*(.*)$/);
        if (match) return { value: match[1], unit: match[2] };
        return { value: str, unit: defaultUnit };
    }

    function pad(n) { return n < 10 ? "0" + n : "" + n }

    // ===================== Clock (unchanged logic) =====================
    property var now: new Date()
    Timer { interval: 250; running: true; repeat: true; onTriggered: root.now = new Date() }

    readonly property int    _h24: now.getHours()
    readonly property string hh:   sensorBackend.rtcFault ? "--" : (use24h ? pad(_h24) : ("" + (((_h24 % 12) === 0) ? 12 : (_h24 % 12))))
    readonly property string mm:   sensorBackend.rtcFault ? "--" : pad(now.getMinutes())
    readonly property string ss:   sensorBackend.rtcFault ? "--" : pad(now.getSeconds())
    readonly property string ampm: sensorBackend.rtcFault ? "" : (use24h ? "" : (_h24 >= 12 ? "PM" : "AM"))
    readonly property bool clockFault: sensorBackend.rtcFault

    readonly property var _days:   ["SUNDAY","MONDAY","TUESDAY","WEDNESDAY","THURSDAY","FRIDAY","SATURDAY"]
    readonly property var _months: ["JAN","FEB","MAR","APR","MAY","JUN","JUL","AUG","SEP","OCT","NOV","DEC"]
    readonly property string dateLine: sensorBackend.rtcFault ? "RTC FAULT"
        : (_days[now.getDay()] + "  ·  " + now.getDate() + " " + _months[now.getMonth()] + " " + now.getFullYear())

    // ===================== Responsive scale =====================
    readonly property real u: Math.min(width / 1920, height / 1080)
    readonly property real heroClockSlotWidth: 920 * u
    readonly property real heroClockSlotHeight: 340 * u

    // ===================== Sensor model =====================
    // Editorial principle: monochrome by default, vermillion ONLY on alarm.
    readonly property var sensors: [
        {
            "label": "TEMPERATURE",
            "value": splitValueAndUnit(sensorBackend.temperature, "°C").value,
            "unit": "°C",
            "alert": (sensorBackend.alarmState & 1) !== 0,
            "history": sensorBackend.tempHistory
        },
        {
            "label": "HUMIDITY",
            "value": splitValueAndUnit(sensorBackend.humidity, "%").value,
            "unit": "%RH",
            "alert": (sensorBackend.alarmState & 2) !== 0,
            "history": sensorBackend.humidityHistory
        },
        {
            "label": "ILLUMINANCE",
            "value": splitValueAndUnit(sensorBackend.light, "lx").value,
            "unit": "lx",
            "alert": false,
            "history": sensorBackend.lightHistory
        }
    ]

    // ===================== Layout (Pure Anchors for Absolute Stability) =====================
    Item {
        id: mainContainer
        x: 92 * u
        y: 80 * u
        width: root.width - (184 * u)
        height: root.height - (160 * u)

        // ---------- Top row: title (left) · date (right) ----------
        RowLayout {
            id: headerRow
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: 30 * u

            Text {
                text: "ENVIRONMENT MONITORING"
                color: root.inkColor
                font.family: root.fontFamily
                font.pixelSize: 15 * u
                font.weight: Font.Bold
                font.letterSpacing: 2.7 * u
                Behavior on color { ColorAnimation { duration: 400 } }
            }
            Item { Layout.fillWidth: true }
            Text {
                text: root.dateLine
                color: root.mutedColor
                font.family: root.fontFamily
                font.pixelSize: 15 * u
                font.weight: Font.Bold
                font.letterSpacing: 2.7 * u
                Behavior on color { ColorAnimation { duration: 400 } }
            }
        }

        // ---------- Thick rule ----------
        Rectangle {
            id: headerDivider
            anchors.top: headerRow.bottom
            anchors.topMargin: 20 * u
            anchors.left: parent.left
            anchors.right: parent.right
            height: 2 * u
            color: root.inkColor
            Behavior on color { ColorAnimation { duration: 400 } }
        }

        // ---------- Bottom: 3-column grid (Locked to bottom) ----------
        RowLayout {
            id: bottomGrid
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            height: 320 * u
            spacing: 0

            Repeater {
                model: root.sensors
                delegate: RowLayout {
                    id: colWrap
                    required property int index
                    required property var modelData
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 0

                    // Vertical hairline divider (not before first column)
                    Rectangle {
                        visible: colWrap.index !== 0
                        Layout.fillHeight: true
                        Layout.topMargin: 34 * u
                        Layout.bottomMargin: 6 * u
                        width: 1 * u
                        color: root.hairColor
                        Behavior on color { ColorAnimation { duration: 400 } }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.leftMargin:  colWrap.index === 0 ? 0 : 40 * u
                        Layout.rightMargin: colWrap.index === root.sensors.length - 1 ? 0 : 40 * u
                        Layout.topMargin: 34 * u
                        spacing: 0

                        // Column label
                        Text {
                            text: colWrap.modelData.label
                            color: root.inkColor
                            font.family: root.fontFamily
                            font.pixelSize: 14 * u
                            font.weight: Font.Bold
                            font.letterSpacing: 2.2 * u
                            Behavior on color { ColorAnimation { duration: 400 } }
                        }

                        // Big number + unit container (using baseline anchoring for perfect alignment)
                        Item {
                            Layout.topMargin: 20 * u
                            Layout.preferredHeight: 140 * u
                            Layout.minimumHeight: 140 * u
                            Layout.maximumHeight: 140 * u
                            Layout.fillWidth: true
                            height: 140 * u
                            implicitHeight: 140 * u

                            Text {
                                id: valText
                                text: colWrap.modelData.value
                                color: colWrap.modelData.alert ? root.accent : root.inkColor
                                font.family: root.fontFamily
                                font.pixelSize: 118 * u
                                font.weight: Font.Bold
                                font.letterSpacing: -3.5 * u
                                anchors.bottom: parent.bottom
                                anchors.left: parent.left
                                Behavior on color { ColorAnimation { duration: 400 } }
                            }

                            Text {
                                text: colWrap.modelData.unit
                                color: root.unitColor
                                font.family: root.fontFamily
                                font.pixelSize: 34 * u
                                font.weight: Font.Medium
                                anchors.baseline: valText.baseline
                                anchors.left: valText.right
                                anchors.leftMargin: 8 * u
                                Behavior on color { ColorAnimation { duration: 400 } }
                            }
                        }

                        // Minimal sparkline (Always occupies 70px)
                        Canvas {
                            id: spark
                            Layout.fillWidth: true
                            Layout.preferredHeight: 70 * u
                            Layout.minimumHeight: 70 * u
                            Layout.maximumHeight: 70 * u
                            Layout.topMargin: 14 * u
                            height: 70 * u
                            implicitHeight: 70 * u
                            property var history: colWrap.modelData.history
                            property bool alert: colWrap.modelData.alert
                            property color lineColor: alert ? root.accent : root.inkColor
                            onHistoryChanged: requestPaint()
                            onLineColorChanged: requestPaint()
                            onWidthChanged: requestPaint()
                            onPaint: {
                                var ctx = getContext("2d")
                                ctx.reset()
                                if (!history || history.length < 2) return
                                var w = width, h = height, pad = 7 * u
                                var mn = history[0], mx = history[0]
                                for (var i = 1; i < history.length; i++) {
                                    if (history[i] < mn) mn = history[i]
                                    if (history[i] > mx) mx = history[i]
                                }
                                var r = (mx - mn) || 1
                                var stepX = w / (history.length - 1)
                                ctx.strokeStyle = lineColor
                                ctx.lineWidth = 2.5 * u
                                ctx.lineCap = "round"
                                ctx.lineJoin = "round"
                                ctx.beginPath()
                                for (var j = 0; j < history.length; j++) {
                                    var x = j * stepX
                                    var y = h - pad - ((history[j] - mn) / r) * (h - 2 * pad)
                                    if (j === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y)
                                }
                                ctx.stroke()
                            }
                        }

                        Item { Layout.fillHeight: true }

                        // Status line
                        RowLayout {
                            visible: colWrap.modelData.label !== "ILLUMINANCE"
                            Layout.topMargin: 14 * u
                            spacing: 10 * u
                            Rectangle {
                                width: 8 * u; height: 8 * u; radius: 4 * u
                                Layout.alignment: Qt.AlignVCenter
                                color: colWrap.modelData.alert ? root.accent : root.statColor
                                Behavior on color { ColorAnimation { duration: 400 } }
                            }
                            Text {
                                text: {
                                    if (colWrap.modelData.alert) {
                                        if (colWrap.modelData.label === "TEMPERATURE") {
                                            var diff = (parseNumber(sensorBackend.temperature) - sensorBackend.tempAlarmLimit);
                                            return "ELEVATED · +" + diff.toFixed(1) + " OVER SET";
                                        }
                                        return "ALERT · OUT OF BAND";
                                    }
                                    return "NOMINAL · WITHIN BAND";
                                }
                                color: colWrap.modelData.alert ? root.accent : root.statColor
                                font.family: root.fontFamily
                                font.pixelSize: 14 * u
                                font.weight: Font.Bold
                                font.letterSpacing: 2.2 * u
                                Behavior on color { ColorAnimation { duration: 400 } }
                            }
                        }
                    }
                }
            }
        }

        // ---------- Hero: clock (left) · seconds meta (right) (Anchored to remaining space) ----------
        RowLayout {
            id: clockArea
            anchors.top: headerDivider.bottom
            anchors.bottom: bottomGrid.top
            anchors.left: parent.left
            anchors.right: parent.right
            spacing: 0

            Item {
                Layout.alignment: Qt.AlignVCenter
                width: root.clockFault ? (598 * u) : normalClock.width
                height: root.clockFault ? (176 * u) : normalClock.height
                implicitWidth: width
                implicitHeight: height

                Row {
                    id: normalClock
                    visible: !root.clockFault
                    spacing: 0
                    Text {
                        text: root.hh
                        color: root.inkColor
                        font.family: root.fontFamily
                        font.pixelSize: 336 * u
                        font.weight: Font.Bold
                        font.letterSpacing: -8 * u
                        renderType: Text.NativeRendering
                        Behavior on color { ColorAnimation { duration: 400 } }
                    }
                    Text {
                        text: ":"
                        color: root.accent
                        font.family: root.fontFamily
                        font.pixelSize: 336 * u
                        font.weight: Font.Bold
                        renderType: Text.NativeRendering
                    }
                    Text {
                        text: root.mm
                        color: root.inkColor
                        font.family: root.fontFamily
                        font.pixelSize: 336 * u
                        font.weight: Font.Bold
                        font.letterSpacing: -8 * u
                        renderType: Text.NativeRendering
                        Behavior on color { ColorAnimation { duration: 400 } }
                    }
                }

                // The RTC fault placeholder stays as "--:--", but uses fixed
                // geometry instead of giant hyphen glyphs so it remains centered.
                RowLayout {
                    visible: root.clockFault
                    anchors.centerIn: parent
                    spacing: 44 * u

                    Item {
                        implicitWidth: 240 * u
                        implicitHeight: 88 * u

                        Row {
                            anchors.centerIn: parent
                            spacing: 24 * u
                            Repeater {
                                model: 2
                                delegate: Rectangle {
                                    width: 108 * u
                                    height: 18 * u
                                    radius: 2 * u
                                    color: root.inkColor
                                }
                            }
                        }
                    }

                    Item {
                        implicitWidth: 30 * u
                        implicitHeight: 88 * u

                        Column {
                            anchors.centerIn: parent
                            spacing: 28 * u
                            Repeater {
                                model: 2
                                delegate: Rectangle {
                                    width: 30 * u
                                    height: 30 * u
                                    color: root.accent
                                }
                            }
                        }
                    }

                    Item {
                        implicitWidth: 240 * u
                        implicitHeight: 88 * u

                        Row {
                            anchors.centerIn: parent
                            spacing: 24 * u
                            Repeater {
                                model: 2
                                delegate: Rectangle {
                                    width: 108 * u
                                    height: 18 * u
                                    radius: 2 * u
                                    color: root.inkColor
                                }
                            }
                        }
                    }
                }
            }

            Item { Layout.fillWidth: true }

            // Seconds meta (right, baseline-aligned low)
            ColumnLayout {
                Layout.alignment: Qt.AlignBottom
                Layout.bottomMargin: 30 * u
                spacing: 8 * u
                Text {
                    Layout.alignment: Qt.AlignRight
                    text: root.clockFault ? "--\u2033"
                                          : (root.ampm !== "" ? root.ampm + "  " : "") + root.ss + "\u2033"
                    color: root.inkColor
                    font.family: root.fontFamily
                    font.pixelSize: 44 * u
                    font.weight: Font.DemiBold
                    renderType: Text.NativeRendering
                    Behavior on color { ColorAnimation { duration: 400 } }
                }
                Text {
                    Layout.alignment: Qt.AlignRight
                    text: root.use24h ? "SECONDS · 24H" : "SECONDS · 12H"
                    color: root.mutedColor
                    font.family: root.fontFamily
                    font.pixelSize: 14 * u
                    font.weight: Font.Bold
                    font.letterSpacing: 2.8 * u
                    Behavior on color { ColorAnimation { duration: 400 } }
                }
            }
        }
    }
}
