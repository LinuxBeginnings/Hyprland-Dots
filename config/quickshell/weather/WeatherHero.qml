// Current weather hero card displaying condition icon, temperature, and metrics.

import QtQuick
import QtQuick.Layouts

Rectangle {
    id: hero

    property var theme: null
    property var location: null
    property var settings: null

    radius: 12
    color: theme ? theme.surface : "#232326"
    border.width: 1
    border.color: theme ? theme.border : "#3a3a3f"
    implicitHeight: 180

    readonly property var current: location ? location.current : null
    readonly property string unitMode: settings ? (settings.unit || "c") : "c"

    function formatTemp(tempC, tempF) {
        if (tempC === undefined || tempC === null) return "--";
        if (hero.unitMode === "f") return tempF + "°F";
        if (hero.unitMode === "both") return tempC + "°C / " + tempF + "°F";
        return tempC + "°C";
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 10

        // Location & Condition Header
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Text {
                text: hero.location ? hero.location.name : "Location"
                color: hero.theme ? hero.theme.text : "#ffffff"
                font.family: hero.theme ? hero.theme.fontFamily : "sans-serif"
                font.pixelSize: 15
                font.bold: true
                elide: Text.ElideRight
                Layout.fillWidth: true
            }

            Rectangle {
                visible: hero.location ? Boolean(hero.location.is_auto) : false
                implicitWidth: autoRow.implicitWidth + 10
                implicitHeight: 22
                radius: 11
                color: hero.theme ? hero.theme.surfaceAlt : "#2c2c30"

                RowLayout {
                    id: autoRow
                    anchors.centerIn: parent
                    spacing: 4

                    Text {
                        text: "󰍎"
                        font.family: hero.theme ? hero.theme.iconFont : "sans-serif"
                        font.pixelSize: 11
                        color: hero.theme ? hero.theme.accent : "#cba6f7"
                    }

                    Text {
                        text: "Auto"
                        font.family: hero.theme ? hero.theme.fontFamily : "sans-serif"
                        font.pixelSize: 10
                        font.bold: true
                        color: hero.theme ? hero.theme.muted : "#a9a3ab"
                    }
                }
            }
        }

        // Main Weather Display (Icon + Big Temp + Description)
        RowLayout {
            Layout.fillWidth: true
            spacing: 16

            Text {
                text: hero.current ? hero.current.icon : ""
                font.family: hero.theme ? hero.theme.iconFont : "sans-serif"
                font.pixelSize: 48
                color: hero.theme ? hero.theme.accent : "#cba6f7"
            }

            ColumnLayout {
                spacing: 2
                Layout.fillWidth: true

                Text {
                    text: hero.current ? hero.formatTemp(hero.current.temp_c, hero.current.temp_f) : "--°"
                    font.family: hero.theme ? hero.theme.fontFamily : "sans-serif"
                    font.pixelSize: 32
                    font.bold: true
                    color: hero.theme ? hero.theme.text : "#ffffff"
                }

                Text {
                    text: hero.current ? hero.current.condition : "Loading weather…"
                    font.family: hero.theme ? hero.theme.fontFamily : "sans-serif"
                    font.pixelSize: 13
                    color: hero.theme ? hero.theme.muted : "#a9a3ab"
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: hero.theme ? hero.theme.border : "#3a3a3f"
            opacity: 0.5
        }

        // Metrics Grid (Feels Like, Humidity, Wind)
        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            // Feels Like
            RowLayout {
                Layout.fillWidth: true
                spacing: 6
                Text {
                    text: "󰔄"
                    font.family: hero.theme ? hero.theme.iconFont : "sans-serif"
                    font.pixelSize: 14
                    color: hero.theme ? hero.theme.muted : "#a9a3ab"
                }
                Text {
                    text: "Feels: " + (hero.current ? hero.formatTemp(hero.current.feels_c, hero.current.feels_f) : "--")
                    font.family: hero.theme ? hero.theme.fontFamily : "sans-serif"
                    font.pixelSize: 11
                    color: hero.theme ? hero.theme.text : "#ffffff"
                }
            }

            // Humidity
            RowLayout {
                Layout.fillWidth: true
                spacing: 6
                Text {
                    text: ""
                    font.family: hero.theme ? hero.theme.iconFont : "sans-serif"
                    font.pixelSize: 14
                    color: hero.theme ? hero.theme.info : "#89b4fa"
                }
                Text {
                    text: "Humidity: " + (hero.current ? (hero.current.humidity + "%") : "--")
                    font.family: hero.theme ? hero.theme.fontFamily : "sans-serif"
                    font.pixelSize: 11
                    color: hero.theme ? hero.theme.text : "#ffffff"
                }
            }

            // Wind
            RowLayout {
                Layout.fillWidth: true
                spacing: 6
                Text {
                    text: "󰠠"
                    font.family: hero.theme ? hero.theme.iconFont : "sans-serif"
                    font.pixelSize: 14
                    color: hero.theme ? hero.theme.good : "#a6e3a1"
                }
                Text {
                    text: "Wind: " + (hero.current ? (hero.current.wind_speed + " " + hero.current.wind_unit) : "--")
                    font.family: hero.theme ? hero.theme.fontFamily : "sans-serif"
                    font.pixelSize: 11
                    color: hero.theme ? hero.theme.text : "#ffffff"
                }
            }
        }
    }
}
