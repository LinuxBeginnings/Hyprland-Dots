// Under Construction placeholder card with icons and roadmap badges

import QtQuick
import QtQuick.Layouts

Item {
    id: card

    property var theme: null
    property string featureTitle: "Waybar Visual Editor"
    property string phase: "Phase 2"
    property string note: "Full visual bar layout, module arranger, and stylesheet builder is scheduled for Phase 2."
    property string quickActionText: "Open Waybar Font & Size Settings"
    signal quickActionTriggered()

    Rectangle {
        anchors.fill: parent
        color: theme ? theme.surface : "#1c1c20"
        border.width: 1
        border.color: theme ? theme.border : "#303036"
        radius: 10

        ColumnLayout {
            anchors.centerIn: parent
            spacing: 16
            width: Math.min(520, parent.width - 40)

            // Construction Icon Badge
            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                width: 72
                height: 72
                radius: 36
                color: theme ? theme.surfaceAlt : "#26262e"
                border.width: 2
                border.color: theme ? theme.warning : "#f9e2af"

                Text {
                    anchors.centerIn: parent
                    text: "🚧"
                    font.pixelSize: 36
                }
            }

            // Title
            Text {
                Layout.alignment: Qt.AlignHCenter
                text: card.featureTitle
                font.family: theme ? theme.fontFamily : "sans-serif"
                font.pixelSize: 18
                font.bold: true
                color: theme ? theme.text : "#ffffff"
            }

            // Phase Badge
            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                implicitWidth: phaseLabel.implicitWidth + 16
                implicitHeight: 24
                radius: 12
                color: theme ? theme.warning : "#f9e2af"

                Text {
                    id: phaseLabel
                    anchors.centerIn: parent
                    text: "Under Construction • " + card.phase
                    font.family: theme ? theme.fontFamily : "sans-serif"
                    font.pixelSize: 11
                    font.bold: true
                    color: "#16161a"
                }
            }

            // Description Note
            Text {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignHCenter
                text: card.note
                font.family: theme ? theme.fontFamily : "sans-serif"
                font.pixelSize: 12
                color: theme ? theme.muted : "#999999"
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                lineHeight: 1.3
            }

            // Quick Action Button (e.g. Open Waybar Font Settings)
            Rectangle {
                visible: !!card.quickActionText
                Layout.alignment: Qt.AlignHCenter
                implicitWidth: actionBtnText.implicitWidth + 24
                implicitHeight: 34
                radius: 6
                color: actionMouse.containsMouse ? (theme ? theme.hover : "#2c2c34") : (theme ? theme.surfaceAlt : "#222228")
                border.width: 1
                border.color: theme ? theme.accent : "#cba6f7"

                Text {
                    id: actionBtnText
                    anchors.centerIn: parent
                    text: "󰹯 " + card.quickActionText
                    font.family: theme ? theme.fontFamily : "sans-serif"
                    font.pixelSize: 12
                    font.bold: true
                    color: theme ? theme.accent : "#cba6f7"
                }

                MouseArea {
                    id: actionMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: card.quickActionTriggered()
                }
            }
        }
    }
}
