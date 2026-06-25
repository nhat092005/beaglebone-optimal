import QtQuick
import QtQuick.Window
import QtQuick.Layouts

Window {
    id: root
    width: 1920
    height: 1080
    visible: true
    color: bgColor
    title: "BeagleBone Optimal Dashboard"

    // ---------- Theme Configurations (Smooth transition) ----------
    readonly property bool isDark: sensorBackend.nightMode === 1
    readonly property color bgColor: isDark ? "#0F172A" : "#F8FAFC"
    readonly property color cardBg: isDark ? "#1E293B" : "#FFFFFF"
    readonly property color cardBorderColor: isDark ? "#334155" : "#E2E8F0"
    readonly property color textMainColor: isDark ? "#F8FAFC" : "#0F172A"
    readonly property color textMutedColor: isDark ? "#94A3B8" : "#475569"

    Behavior on color { ColorAnimation { duration: 400 } }

    // ---------- Real Sensor Data Bindings ----------
    property real temperature: parseNumber(sensorBackend.temperature)
    property real humidity:    parseNumber(sensorBackend.humidity)
    property real light:       parseNumber(sensorBackend.light)

    // ---------- Clock Options ----------
    property bool use24h:      true
    property bool showSeconds:  true       // Toggle seconds progress circle

    // ---------- Font Configurations ----------
    // Note: Default app font is DejaVu Sans, initialized in main.cpp.
    readonly property string fontFamily: "DejaVu Sans"

    // Helper functions for parsing sensor strings from C++ backend
    function parseNumber(str) {
        if (!str || str === "--") return 0.0;
        var num = parseFloat(str.replace(/[^0-9.-]/g, ""));
        return isNaN(num) ? 0.0 : num;
    }

    // Helper to calculate clean tick intervals for charts
    function getCleanTicks(minVal, maxVal) {
        var range = maxVal - minVal;
        if (range <= 0) range = 1.0;

        // Subtract/add a margin to prevent points hugging the very top/bottom edges
        var adjustedMin = minVal - range * 0.15;
        var adjustedMax = maxVal + range * 0.15;
        var adjRange = adjustedMax - adjustedMin;

        var rawStep = adjRange / 3.0; // Target ~3 intervals
        var magnitude = Math.pow(10, Math.floor(Math.log(rawStep) / Math.LN10));
        if (isNaN(magnitude) || magnitude <= 0) magnitude = 1.0;
        var normalized = rawStep / magnitude;

        var step;
        if (normalized < 1.5) step = 1 * magnitude;
        else if (normalized < 3.0) step = 2 * magnitude;
        else if (normalized < 7.0) step = 5 * magnitude;
        else step = 10 * magnitude;

        var tickMin = Math.floor(adjustedMin / step) * step;
        var tickMax = Math.ceil(adjustedMax / step) * step;

        var ticks = [];
        // Prevent floating point rounding accumulation issues in loop
        for (var v = tickMin; v <= tickMax + (step * 0.01); v += step) {
            ticks.push(v);
        }

        return { "ticks": ticks, "min": tickMin, "max": tickMax };
    }

    function splitValueAndUnit(str, defaultUnit) {
        if (!str || str === "--") {
            return { value: "--", unit: defaultUnit };
        }
        var match = str.match(/^([0-9.-]+)\s*(.*)$/);
        if (match) {
            return { value: match[1], unit: match[2] };
        }
        return { value: str, unit: defaultUnit };
    }

    // ===================== Clock Logic =====================
    property var now: new Date()
    Timer { interval: 250; running: true; repeat: true; onTriggered: root.now = new Date() }

    function pad(n) { return n < 10 ? "0" + n : "" + n }
    readonly property int    _h24:    now.getHours()
    readonly property string hh:      sensorBackend.rtcFault ? "--" : (use24h ? pad(_h24) : ("" + (((_h24 % 12) === 0) ? 12 : (_h24 % 12))))
    readonly property string mm:      sensorBackend.rtcFault ? "--" : pad(now.getMinutes())
    readonly property string ss:      sensorBackend.rtcFault ? "--" : pad(now.getSeconds())
    readonly property string ampm:    sensorBackend.rtcFault ? "" : (use24h ? "" : (_h24 >= 12 ? "PM" : "AM"))
    readonly property real   secFrac: (now.getSeconds() + now.getMilliseconds() / 1000) / 60

    readonly property var _days:   ["SUNDAY","MONDAY","TUESDAY","WEDNESDAY","THURSDAY","FRIDAY","SATURDAY"]
    readonly property var _months: ["JAN","FEB","MAR","APR","MAY","JUN","JUL","AUG","SEP","OCT","NOV","DEC"]
    readonly property string dateLine: sensorBackend.rtcFault ? "RTC FAULT"
                                       : (_days[now.getDay()] + "  ·  " + now.getDate()
                                          + " " + _months[now.getMonth()] + " " + now.getFullYear())

    // ===================== Responsive Scaling =====================
    readonly property real u: width / 1920

    // ===================== Sensor Model (With Alerts and History) =====================
    readonly property var sensors: [
        {
            "label": "Temp",
            "value": splitValueAndUnit(sensorBackend.temperature, "°C").value,
            "unit": "°C",
            "alert": (sensorBackend.alarmState & 1) !== 0,
            "alertColor": "#EF4444",
            "accent": "#EF4444",
            "labelColor": (sensorBackend.alarmState & 1) !== 0 ? "#EF4444" : (isDark ? "#F87171" : "#F97316"),
            "valueColor": (sensorBackend.alarmState & 1) !== 0 ? "#EF4444" : root.textMainColor,
            "history": sensorBackend.tempHistory
        },
        {
            "label": "Humidity",
            "value": splitValueAndUnit(sensorBackend.humidity, "%").value,
            "unit": "%",
            "alert": (sensorBackend.alarmState & 2) !== 0,
            "alertColor": "#3B82F6",
            "accent": "#3B82F6",
            "labelColor": (sensorBackend.alarmState & 2) !== 0 ? "#3B82F6" : (isDark ? "#60A5FA" : "#3B82F6"),
            "valueColor": (sensorBackend.alarmState & 2) !== 0 ? "#3B82F6" : root.textMainColor,
            "history": sensorBackend.humidityHistory
        },
        {
            "label": "Light",
            "value": splitValueAndUnit(sensorBackend.light, "lx").value,
            "unit": "lx",
            "alert": false,
            "alertColor": "transparent",
            "accent": "#EAB308",
            "labelColor": isDark ? "#FDE047" : "#D97706",
            "valueColor": root.textMainColor,
            "history": sensorBackend.lightHistory
        }
    ]

    // ===================== Main Panel =====================
    Item {
        id: mainContainer
        anchors.fill: parent
        anchors.leftMargin:   115 * u
        anchors.rightMargin:  115 * u
        anchors.topMargin:     76 * u
        anchors.bottomMargin:  76 * u

        ColumnLayout {
            anchors.fill: parent
            anchors.leftMargin:   64 * u
            anchors.rightMargin:  64 * u
            anchors.topMargin:    32 * u
            anchors.bottomMargin: 32 * u
            spacing: 0

            // ---------- Top Row: Date & Seconds ----------
            RowLayout {
                Layout.fillWidth: true
                spacing: 0

                // Date on Left
                Text {
                    Layout.fillWidth: true
                    text: root.dateLine
                    color: root.textMutedColor
                    font.family: root.fontFamily
                    font.pixelSize: 22 * u
                    font.weight: Font.DemiBold
                    font.letterSpacing: 4 * u
                    Behavior on color { ColorAnimation { duration: 400 } }
                }

                // Seconds Ring on Right
                Item {
                    visible: root.showSeconds && !sensorBackend.rtcFault
                    Layout.preferredWidth:  72 * u
                    Layout.preferredHeight: 72 * u
                    Layout.alignment: Qt.AlignVCenter

                    Canvas {
                        id: ring
                        anchors.fill: parent
                        property real frac: root.secFrac
                        property bool darkTheme: root.isDark
                        onFracChanged: requestPaint()
                        onWidthChanged: requestPaint()
                        onDarkThemeChanged: requestPaint()
                        onPaint: {
                            var ctx = getContext("2d")
                            ctx.reset()
                            var w = width
                            var cx = w / 2, cy = w / 2
                            var lw = w * 2.5 / 44
                            var r  = w / 2 * (18 / 22) - lw / 2

                            // Track
                            ctx.beginPath()
                            ctx.arc(cx, cy, r, 0, 2 * Math.PI)
                            ctx.lineWidth = lw
                            ctx.strokeStyle = darkTheme ? "#334155" : "#E2E8F0"
                            ctx.stroke()

                            // Progress arc (clockwise from top)
                            ctx.beginPath()
                            ctx.arc(cx, cy, r, -Math.PI / 2, -Math.PI / 2 + 2 * Math.PI * frac)
                            ctx.lineWidth = lw
                            ctx.lineCap = "round"
                            ctx.strokeStyle = "#3B82F6"
                            ctx.stroke()
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: root.ss
                        color: root.textMutedColor
                        font.family: root.fontFamily
                        font.pixelSize: 20 * u
                        font.weight: Font.DemiBold
                        Behavior on color { ColorAnimation { duration: 400 } }
                    }
                }
            }

            // ---------- Middle Row: Clock Panel ----------
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                Row {
                    anchors.centerIn: parent

                    Text {
                        text: root.hh
                        color: root.textMainColor
                        font.family: root.fontFamily
                        font.pixelSize: 250 * u
                        font.weight: Font.Bold
                        font.letterSpacing: -2 * u
                        Behavior on color { ColorAnimation { duration: 400 } }
                    }
                    Text {
                        id: colon
                        text: ":"
                        color: "#3B82F6"
                        font.family: root.fontFamily
                        font.pixelSize: 250 * u
                        font.weight: Font.Bold
                    }
                    Text {
                        text: root.mm
                        color: root.textMainColor
                        font.family: root.fontFamily
                        font.pixelSize: 250 * u
                        font.weight: Font.Bold
                        font.letterSpacing: -2 * u
                        Behavior on color { ColorAnimation { duration: 400 } }
                    }
                    Text {
                        text: root.ampm
                        visible: root.ampm !== ""
                        color: root.textMutedColor
                        leftPadding: 16 * u
                        anchors.top: parent.top
                        topPadding: 32 * u
                        font.family: root.fontFamily
                        font.pixelSize: 64 * u
                        font.weight: Font.Bold
                        Behavior on color { ColorAnimation { duration: 400 } }
                    }
                }
            }

            // ---------- Bottom Row: Sensor Cards ----------
            RowLayout {
                Layout.fillWidth: true
                spacing: 32 * u

                Repeater {
                    model: root.sensors
                    delegate: Rectangle {
                        id: cardRect
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        Layout.preferredHeight: 370 * u
                        radius: 16 * u
                        color: root.cardBg

                        Behavior on color { ColorAnimation { duration: 400 } }

                        // Alert animators
                        property bool alertActive: modelData.alert
                        property color alertColor: modelData.alertColor
                        property color animatedColor: root.cardBorderColor

                        SequentialAnimation {
                            running: cardRect.alertActive
                            loops: Animation.Infinite
                            ColorAnimation { target: cardRect; property: "animatedColor"; from: cardRect.alertColor; to: root.cardBorderColor; duration: 500; easing.type: Easing.InOutQuad }
                            ColorAnimation { target: cardRect; property: "animatedColor"; from: root.cardBorderColor; to: cardRect.alertColor; duration: 500; easing.type: Easing.InOutQuad }
                        }

                        border.color: cardRect.alertActive ? cardRect.animatedColor : root.cardBorderColor
                        border.width: cardRect.alertActive ? 2.5 * u : 1 * u

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 28 * u
                            spacing: 0

                            // Top row: Label and Alert bubble
                            RowLayout {
                                Layout.fillWidth: true

                                Text {
                                    text: modelData.label
                                    color: modelData.labelColor
                                    font.family: root.fontFamily
                                    font.pixelSize: 20 * u
                                    font.weight: Font.Bold
                                    font.letterSpacing: 1.5 * u
                                    Behavior on color { ColorAnimation { duration: 400 } }
                                }

                                Item { Layout.fillWidth: true } // spacer

                                // Alert Pill
                                Rectangle {
                                    visible: modelData.alert
                                    color: modelData.alertColor
                                    radius: 20 * u
                                    implicitWidth: 82 * u
                                    implicitHeight: 28 * u

                                    Text {
                                        anchors.centerIn: parent
                                        text: "ALERT"
                                        color: "#FFFFFF"
                                        font.family: root.fontFamily
                                        font.pixelSize: 12 * u
                                        font.weight: Font.Bold
                                    }
                                }
                            }

                            // Middle: Value display
                            RowLayout {
                                spacing: 4 * u
                                Text {
                                    text: modelData.value
                                    color: modelData.valueColor
                                    font.family: root.fontFamily
                                    font.pixelSize: 48 * u
                                    font.weight: Font.Bold
                                    Behavior on color { ColorAnimation { duration: 400 } }
                                }
                                Text {
                                    text: modelData.unit
                                    color: root.textMutedColor
                                    Layout.alignment: Qt.AlignBottom
                                    Layout.bottomMargin: 8 * u
                                    font.family: root.fontFamily
                                    font.pixelSize: 22 * u
                                    font.weight: Font.Medium
                                    Behavior on color { ColorAnimation { duration: 400 } }
                                }
                                Item { Layout.fillWidth: true } // spacer
                            }

                            Item { Layout.fillHeight: true } // spacer to push chart down

                            // Historical Line Chart with Axis and Labels
                            Canvas {
                                id: chartCanvas
                                Layout.fillWidth: true
                                Layout.preferredHeight: 160 * u
                                property var history: modelData.history
                                property color cardColor: cardRect.color
                                onHistoryChanged: requestPaint()
                                onWidthChanged: requestPaint()
                                onCardColorChanged: requestPaint()
                                onPaint: {
                                    var ctx = getContext("2d")
                                    ctx.reset()
                                    if (!history || history.length === 0) return

                                    var w = width
                                    var h = height

                                    // Reserved margins
                                    var marginLeft = 45 * u
                                    var marginRight = 10 * u
                                    var marginTop = 15 * u
                                    var marginBottom = 20 * u

                                    var pw = w - marginLeft - marginRight
                                    var ph = h - marginTop - marginBottom

                                    // Find min and max
                                    var rawMin = history[0]
                                    var rawMax = history[0]
                                    for (var i = 1; i < history.length; i++) {
                                        if (history[i] < rawMin) rawMin = history[i]
                                        if (history[i] > rawMax) rawMax = history[i]
                                    }

                                    // Get clean rounded ticks
                                    var scale = root.getCleanTicks(rawMin, rawMax)
                                    var minVal = scale.min
                                    var maxVal = scale.max
                                    var ticks = scale.ticks

                                    var valRange = maxVal - minVal
                                    if (valRange <= 0) valRange = 1.0

                                    // 1. Draw Grid Lines and Y-Axis Labels
                                    ctx.font = "11px " + root.fontFamily
                                    ctx.fillStyle = root.textMutedColor
                                    ctx.textAlign = "right"
                                    ctx.textBaseline = "middle"
                                    ctx.lineWidth = 1 * u

                                    for (var t = 0; t < ticks.length; t++) {
                                        var tickVal = ticks[t]
                                        var tickY = marginTop + ph - ((tickVal - minVal) / valRange) * ph

                                        // Horizontal grid line
                                        ctx.strokeStyle = root.isDark ? "rgba(71, 85, 105, 0.3)" : "rgba(226, 232, 240, 0.5)"
                                        ctx.beginPath()
                                        ctx.moveTo(marginLeft, tickY)
                                        ctx.lineTo(w - marginRight, tickY)
                                        ctx.stroke()

                                        // Left-side label text
                                        var precision = (valRange < 3) ? 1 : 0
                                        var labelStr = tickVal.toFixed(precision)
                                        ctx.fillText(labelStr, marginLeft - 8 * u, tickY)
                                    }

                                    // 2. Draw Y-Axis (Vertical) & X-Axis (Horizontal) Lines
                                    ctx.strokeStyle = root.isDark ? "#475569" : "#CBD5E1"
                                    ctx.lineWidth = 1.5 * u
                                    ctx.beginPath()
                                    // Y-axis
                                    ctx.moveTo(marginLeft, marginTop)
                                    ctx.lineTo(marginLeft, h - marginBottom)
                                    // X-axis
                                    ctx.moveTo(marginLeft, h - marginBottom)
                                    ctx.lineTo(w - marginRight, h - marginBottom)
                                    ctx.stroke()

                                    // 3. Draw Connecting Line for data points
                                    ctx.strokeStyle = modelData.accent
                                    ctx.lineWidth = 3 * u
                                    ctx.lineCap = "round"
                                    ctx.lineJoin = "round"
                                    ctx.beginPath()

                                    var stepX = pw / (history.length - 1)
                                    for (var j = 0; j < history.length; j++) {
                                        var val = history[j]
                                        var x = marginLeft + j * stepX
                                        var y = marginTop + ph - ((val - minVal) / valRange) * ph
                                        if (j === 0) {
                                            ctx.moveTo(x, y)
                                        } else {
                                            ctx.lineTo(x, y)
                                        }
                                    }
                                    ctx.stroke()

                                    // 4. Draw Data Point Dots
                                    ctx.fillStyle = modelData.accent
                                    for (var k = 0; k < history.length; k++) {
                                        var valK = history[k]
                                        var xK = marginLeft + k * stepX
                                        var yK = marginTop + ph - ((valK - minVal) / valRange) * ph
                                        ctx.beginPath()
                                        ctx.arc(xK, yK, 6 * u, 0, 2 * Math.PI)
                                        ctx.fill()

                                        // Outer ring to separate dots from background
                                        ctx.strokeStyle = cardColor
                                        ctx.lineWidth = 2 * u
                                        ctx.stroke()
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
