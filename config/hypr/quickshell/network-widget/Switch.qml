// Small on/off switch for the Wi-Fi and Bluetooth radios.

import QtQuick

Rectangle {
    id: control

    property Theme theme: Theme {}
    property bool checked: false

    signal toggled()

    implicitWidth: 36
    implicitHeight: 19
    radius: height / 2
    color: checked ? theme.accent : theme.surfaceAlt
    border.width: checked ? 0 : 1
    border.color: theme.border

    Rectangle {
        id: knob
        width: 13
        height: 13
        radius: height / 2
        y: (control.height - height) / 2
        x: control.checked ? control.width - width - 3 : 3
        color: control.checked ? control.theme.bg : control.theme.muted

        Behavior on x {
            NumberAnimation {
                duration: 120
                easing.type: Easing.OutCubic
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: control.toggled()
    }
}
