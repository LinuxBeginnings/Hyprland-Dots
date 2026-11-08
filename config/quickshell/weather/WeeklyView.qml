// 7-day weekly forecast list with condition icons, precipitation, and min/max temperatures.

import QtQuick
import QtQuick.Layouts

Rectangle {
    id: weeklyView

    property var theme: null
    property var dailyData: []
    property var settings: null

    radius: 12
    color: theme ? theme.surface : "#232326"
    border.width: 1
    border.color: theme ? theme.border : "#3a3a3f"
    implicitHeight: 220

    readonly property string unitMode: settings ? (settings.unit || "c") : "c"

    function formatTemp(tempC, tempF) {
        if (tempC === undefined || tempC === null) return "--";
        if (weeklyView.unitMode === "f") return tempF + "°";
        if (weeklyView.unitMode === "both") return tempC + "°/" + tempF + "°";
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
                text: "󰃭"
                font.family: weeklyView.theme ? weeklyView.theme.iconFont : "sans-serif"
                font.pixelSize: 13
                color: weeklyView.theme ? weeklyView.theme.accent : "#cba6f7"
            }

            Text {
                text: "7-Day Forecast"
                font.family: weeklyView.theme ? weeklyView.theme.fontFamily : "sans-serif"
                font.pixelSize: 12
                font.bold: true
                color: weeklyView.theme ? weeklyView.theme.text : "#ffffff"
            }
        }

        ListView {
            id: dailyList
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 4
            clip: true
            model: weeklyView.dailyData

            delegate: Rectangle {
                width: dailyList.width
                height: 24
                radius: 6
                color: index % 2 === 0 ? "transparent" : (weeklyView.theme ? weeklyView.theme.surfaceAlt : "#2c2c30")

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    spacing: 8

                    Text {
                        text: modelData.day || "--"
                        font.family: weeklyView.theme ? weeklyView.theme.fontFamily : "sans-serif"
                        font.pixelSize: 11
                        font.bold: modelData.day === "Today"
                        color: modelData.day === "Today" ? (weeklyView.theme ? weeklyView.theme.accent : "#cba6f7") : (weeklyView.theme ? weeklyView.theme.text : "#ffffff")
                        Layout.preferredWidth: 45
                    }

                    Text {
                        text: modelData.icon || ""
                        font.family: weeklyView.theme ? weeklyView.theme.iconFont : "sans-serif"
                        font.pixelSize: 14
                        color: weeklyView.theme ? weeklyView.theme.accent : "#cba6f7"
                        Layout.preferredWidth: 20
                    }

                    Text {
                        text: modelData.condition || ""
                        font.family: weeklyView.theme ? weeklyView.theme.fontFamily : "sans-serif"
                        font.pixelSize: 11
                        color: weeklyView.theme ? weeklyView.theme.muted : "#a9a3ab"
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }

                    Text {
                        visible: modelData.pop > 0
                        text: " " + modelData.pop + "%"
                        font.family: weeklyView.theme ? weeklyView.theme.iconFont : "sans-serif"
                        font.pixelSize: 10
                        color: weeklyView.theme ? weeklyView.theme.info : "#89b4fa"
                        Layout.preferredWidth: 45
                    }

                    Text {
                        text: weeklyView.formatTemp(modelData.temp_min_c, modelData.temp_min_f)
                        font.family: weeklyView.theme ? weeklyView.theme.fontFamily : "sans-serif"
                        font.pixelSize: 11
                        color: weeklyView.theme ? weeklyView.theme.muted : "#a9a3ab"
                        horizontalAlignment: Text.AlignRight
                        Layout.preferredWidth: 35
                    }

                    Rectangle {
                        Layout.preferredWidth: 40
                        height: 3
                        radius: 1.5
                        color: weeklyView.theme ? weeklyView.theme.border : "#3a3a3f"
                    }

                    Text {
                        text: weeklyView.formatTemp(modelData.temp_max_c, modelData.temp_max_f)
                        font.family: weeklyView.theme ? weeklyView.theme.fontFamily : "sans-serif"
                        font.pixelSize: 11
                        font.bold: true
                        color: weeklyView.theme ? weeklyView.theme.text : "#ffffff"
                        horizontalAlignment: Text.AlignRight
                        Layout.preferredWidth: 35
                    }
                }
            }
        }
    }
}
