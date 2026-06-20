import QtQuick
import QtQuick.Window

Window {
    id: root
    width: 1920
    height: 1080
    visible: true
    color: "#f4f7fb"
    title: "BeagleBone Optimal Dashboard"

    Rectangle {
        anchors.fill: parent
        color: "#f4f7fb"

        Column {
            anchors.centerIn: parent
            spacing: 72

            Column {
                width: parent.width
                spacing: 18

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: sensorBackend.time
                    color: "#17324d"
                    font.pixelSize: 192
                    font.weight: Font.Light
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: sensorBackend.date
                    color: "#42607b"
                    font.pixelSize: 54
                    font.capitalization: Font.AllUppercase
                }
            }

            Row {
                spacing: 40

                Rectangle {
                    width: 360
                    height: 240
                    radius: 28
                    color: "#ffffff"
                    border.color: "#d8e1eb"
                    border.width: 2

                    Column {
                        anchors.centerIn: parent
                        spacing: 16

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "TEMPERATURE"
                            color: "#5d7890"
                            font.pixelSize: 34
                            font.capitalization: Font.AllUppercase
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: sensorBackend.temperature
                            color: "#17324d"
                            font.pixelSize: 88
                            font.weight: Font.DemiBold
                        }
                    }
                }

                Rectangle {
                    width: 360
                    height: 240
                    radius: 28
                    color: "#ffffff"
                    border.color: "#d8e1eb"
                    border.width: 2

                    Column {
                        anchors.centerIn: parent
                        spacing: 16

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "HUMIDITY"
                            color: "#5d7890"
                            font.pixelSize: 34
                            font.capitalization: Font.AllUppercase
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: sensorBackend.humidity
                            color: "#17324d"
                            font.pixelSize: 88
                            font.weight: Font.DemiBold
                        }
                    }
                }

                Rectangle {
                    width: 360
                    height: 240
                    radius: 28
                    color: "#ffffff"
                    border.color: "#d8e1eb"
                    border.width: 2

                    Column {
                        anchors.centerIn: parent
                        spacing: 16

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "LIGHT"
                            color: "#5d7890"
                            font.pixelSize: 34
                            font.capitalization: Font.AllUppercase
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: sensorBackend.light
                            color: "#17324d"
                            font.pixelSize: 88
                            font.weight: Font.DemiBold
                        }
                    }
                }
            }
        }
    }
}
