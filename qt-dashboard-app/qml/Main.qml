import QtQuick
import QtQuick.Window
import QtQuick.Layouts

Window {
    id: root
    width: 1920
    height: 1080
    visible: true
    color: "#F8FAFC"
    title: "BeagleBone Optimal Dashboard"

    // ---------- Real Sensor Data Bindings ----------
    property real temperature: parseNumber(sensorBackend.temperature)
    property real humidity:    parseNumber(sensorBackend.humidity)
    property real light:       parseNumber(sensorBackend.light)

    // ---------- Alert Thresholds (Automation) ----------
    property real tempHigh:     35.0       // Over limit -> Red warning
    property real humidityHigh: 80.0       // Over limit -> Red warning
    property real lightLow:     20.0       // Under limit -> Gray dim

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
    readonly property string hh:      use24h ? pad(_h24) : ("" + (((_h24 % 12) === 0) ? 12 : (_h24 % 12)))
    readonly property string mm:      pad(now.getMinutes())
    readonly property string ss:      pad(now.getSeconds())
    readonly property string ampm:    use24h ? "" : (_h24 >= 12 ? "PM" : "AM")
    readonly property real   secFrac: (now.getSeconds() + now.getMilliseconds() / 1000) / 60

    readonly property var _days:   ["SUNDAY","MONDAY","TUESDAY","WEDNESDAY","THURSDAY","FRIDAY","SATURDAY"]
    readonly property var _months: ["JAN","FEB","MAR","APR","MAY","JUN","JUL","AUG","SEP","OCT","NOV","DEC"]
    readonly property string dateLine: _days[now.getDay()] + "  ·  " + now.getDate()
                                       + " " + _months[now.getMonth()] + " " + now.getFullYear()

    // ===================== Responsive Scaling =====================
    // All sizes scale with factor 'u'; design base width is 1920px.
    readonly property real u: width / 1920

    // ===================== Icon Helper (SVG -> Data URI) =====================
    function svgIcon(kind, color) {
        var head = "<svg xmlns='http://www.w3.org/2000/svg' width='24' height='24' viewBox='0 0 24 24' "
                 + "fill='none' stroke='" + color + "' stroke-width='2' stroke-linecap='round' stroke-linejoin='round'>"
        var body
        if (kind === "thermometer")
            body = "<path d='M14 14.76V3.5a2.5 2.5 0 0 0-5 0v11.26a4.5 4.5 0 1 0 5 0z'/>"
        else if (kind === "droplet")
            body = "<path d='M12 2.69l5.66 5.66a8 8 0 1 1-11.31 0z'/>"
        else // sun
            body = "<circle cx='12' cy='12' r='4'/><path d='M12 2v2M12 20v2M4.93 4.93l1.41 1.41"
                 + "M17.66 17.66l1.41 1.41M2 12h2M20 12h2M6.34 17.66l-1.41 1.41M19.07 4.93l-1.41 1.41'/>"
        return "data:image/svg+xml;base64," + Qt.btoa(head + body + "</svg>")
    }

    // ===================== Sensor Model (With Alerts) =====================
    readonly property var sensors: [
        {
            "label": "Temperature", "icon": "thermometer",
            "value": splitValueAndUnit(sensorBackend.temperature, "°C").value,
            "unit": "°C",
            "alert": temperature > tempHigh,
            "bg":     temperature > tempHigh ? "#FEF2F2" : "#FFFFFF",
            "border": temperature > tempHigh ? "#FCA5A5" : "#E2E8F0",
            "accent": temperature > tempHigh ? "#EF4444" : "#F97316",
            "labelC": temperature > tempHigh ? "#EF4444" : "#64748B"
        },
        {
            "label": "Humidity", "icon": "droplet",
            "value": splitValueAndUnit(sensorBackend.humidity, "%").value,
            "unit": "%",
            "alert": humidity > humidityHigh,
            "bg":     humidity > humidityHigh ? "#FEF2F2" : "#FFFFFF",
            "border": humidity > humidityHigh ? "#FCA5A5" : "#E2E8F0",
            "accent": humidity > humidityHigh ? "#EF4444" : "#3B82F6",
            "labelC": humidity > humidityHigh ? "#EF4444" : "#64748B"
        },
        {
            "label": "Ambient Light", "icon": "sun",
            "value": splitValueAndUnit(sensorBackend.light, "lx").value,
            "unit": "lx",
            "alert": light < lightLow,
            "bg":     light < lightLow ? "#F1F5F9" : "#FFFFFF",
            "border": light < lightLow ? "#CBD5E1" : "#E2E8F0",
            "accent": light < lightLow ? "#94A3B8" : "#EAB308",
            "labelC": light < lightLow ? "#94A3B8" : "#64748B"
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
                    color: "#475569"
                    font.family: root.fontFamily
                    font.pixelSize: 22 * u
                    font.weight: Font.DemiBold
                    font.letterSpacing: 4 * u
                }

                // Seconds Ring on Right
                Item {
                    visible: root.showSeconds
                    Layout.preferredWidth:  72 * u
                    Layout.preferredHeight: 72 * u
                    Layout.alignment: Qt.AlignVCenter

                    Canvas {
                        id: ring
                        anchors.fill: parent
                        property real frac: root.secFrac
                        onFracChanged: requestPaint()
                        onWidthChanged: requestPaint()
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
                            ctx.strokeStyle = "#E2E8F0"
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
                        color: "#475569"
                        font.family: root.fontFamily
                        font.pixelSize: 20 * u
                        font.weight: Font.DemiBold
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
                        color: "#0F172A"
                        font.family: root.fontFamily
                        font.pixelSize: 250 * u
                        font.weight: Font.Bold
                        font.letterSpacing: -2 * u
                    }
                    Text {
                        id: colon
                        text: ":"
                        color: "#3B82F6"
                        font.family: root.fontFamily
                        font.pixelSize: 250 * u
                        font.weight: Font.Bold
                        SequentialAnimation on opacity {
                            loops: Animation.Infinite
                            NumberAnimation { from: 1.0; to: 0.2; duration: 650; easing.type: Easing.InOutQuad }
                            NumberAnimation { from: 0.2; to: 1.0; duration: 650; easing.type: Easing.InOutQuad }
                        }
                    }
                    Text {
                        text: root.mm
                        color: "#0F172A"
                        font.family: root.fontFamily
                        font.pixelSize: 250 * u
                        font.weight: Font.Bold
                        font.letterSpacing: -2 * u
                    }
                    Text {
                        text: root.ampm
                        visible: root.ampm !== ""
                        color: "#475569"
                        leftPadding: 16 * u
                        anchors.top: parent.top
                        topPadding: 32 * u
                        font.family: root.fontFamily
                        font.pixelSize: 64 * u
                        font.weight: Font.Bold
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
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        Layout.preferredHeight: 140 * u
                        radius: 12 * u
                        color: modelData.bg
                        border.color: modelData.border
                        border.width: 1 * u



                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 24 * u
                            anchors.rightMargin: 24 * u
                            anchors.topMargin: 20 * u
                            anchors.bottomMargin: 20 * u
                            spacing: 20 * u

                            Image {
                                Layout.preferredWidth:  48 * u
                                Layout.preferredHeight: 48 * u
                                sourceSize.width:  48 * u
                                sourceSize.height: 48 * u
                                fillMode: Image.PreserveAspectFit
                                source: root.svgIcon(modelData.icon, modelData.accent)
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 4 * u

                                Text {
                                    text: modelData.label.toUpperCase()
                                    color: modelData.labelC
                                    font.family: root.fontFamily
                                    font.pixelSize: 14 * u
                                    font.weight: Font.DemiBold
                                    font.letterSpacing: 2 * u
                                }
                                RowLayout {
                                    spacing: 4 * u
                                    Text {
                                        text: modelData.value
                                        color: "#0F172A"
                                        font.family: root.fontFamily
                                        font.pixelSize: 42 * u
                                        font.weight: Font.Bold
                                    }
                                    Text {
                                        text: modelData.unit
                                        color: "#475569"
                                        Layout.alignment: Qt.AlignBottom
                                        Layout.bottomMargin: 6 * u
                                        font.family: root.fontFamily
                                        font.pixelSize: 20 * u
                                        font.weight: Font.Medium
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
