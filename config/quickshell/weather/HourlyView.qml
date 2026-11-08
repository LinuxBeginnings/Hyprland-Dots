// Hourly forecast row showing weather conditions throughout the day.

import QtQuick
import QtQuick.Layouts

Rectangle {
    id: hourlyView

    property var theme: null
    property var hourlyData: []
    property var settings: null

    radius: 12
    color: theme ? theme.surface : "#232326"
    border.width: 1
    border.color: theme ? theme.border : "#3a3a3f"
    implicitHeight: 125

    readonly property string unitMode: settings ? (settings.unit || "c") : "c"

    function formatTemp(tempC, tempF) {
        if (tempC === undefined || tempC === null) return "--";
        if (hourlyView.unitMode === "f") return tempF + "°";
        if (hourlyView.unitMode === "both") return tempC + "°/" + tempF + "°";
        return tempC + "°";
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 6

        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            Text {
                text: "󰥔"
                font.family: hourlyView.theme ? hourlyView.theme.iconFont : "sans-serif"
                font.pixelSize: 13
                color: hourlyView.theme ? hourlyView.theme.accent : "#cba6f7"
            }

            Text {
                text: "Hourly Forecast"
                font.family: hourlyView.theme ? hourlyView.theme.fontFamily : "sans-serif"
                font.pixelSize: 12
                font.bold: true
                color: hourlyView.theme ? hourlyView.theme.text : "#ffffff"
            }
        }

        ListView {
            id: hourlyList
            Layout.fillWidth: true
            Layout.fillHeight: true
            orientation: ListView.Horizontal
            spacing: 8
            clip: true
            model: hourlyView.hourlyData

            delegate: Rectangle {
                width: 60
                height: hourlyList.height
                radius: 8
                color: hourlyView.theme ? hourlyView.theme.surfaceAlt : "#2c2c30"
                border.width: 1
                border.color: hourlyView.theme ? hourlyView.theme.border : "#3a3a3f"

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 4

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: modelData.time || "--:--"
                        font.family: hourlyView.theme ? hourlyView.theme.fontFamily : "sans-serif"
                        font.pixelSize: 10
                        color: hourlyView.theme ? hourlyView.theme.muted : "#a9a3ab"
                    }

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: modelData.icon || ""
                        font.family: hourlyView.theme ? hourlyView.theme.iconFont : "sans-serif"
                        font.pixelSize: 20
                        color: hourlyView.theme ? hourlyView.theme.accent : "#cba6f7"
                    }

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: hourlyView.formatTemp(modelData.temp_c, modelData.temp_f)
                        font.family: hourlyView.theme ? hourlyView.theme.fontFamily : "sans-serif"
                        font.pixelSize: 11
                        font.bold: true
                        color: hourlyView.theme ? hourlyView.theme.text : "#ffffff"
                    }

                    Text {
                        visible: modelData.pop > 0
                        Layout.alignment: Qt.AlignHCenter
                        text: " " + modelData.pop + "%"
                        font.family: hourlyView.theme ? hourlyView.theme.iconFont : "sans-serif"
                        font.pixelSize: 9
                        color: hourlyView.theme ? hourlyView.theme.info : "#89b4fa"
                    }
                }
            }
        }
    }
}
