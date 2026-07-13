import QtQuick
import Quickshell

Rectangle {
    id: searchBar
    width: Math.min(parent.width * 0.6, 480)
    height: 40
    radius: 20
    color: "#66000000"
    border.width: 1
    border.color: m3.m3Primary
    anchors.horizontalCenter: parent.horizontalCenter

    property var onTextChanged: null

    function reset() {
      searchInput.text = ""
    }

    function focusInput() {
        searchInput.forceActiveFocus(Qt.ActiveWindowFocusReason)
    }

    function releaseInputFocus() {
        searchInput.focus = false
    }

    TextInput {
        id: searchInput
        anchors.fill: parent
        anchors.leftMargin: 16
        anchors.rightMargin: 16
        verticalAlignment: TextInput.AlignVCenter
        color: "white"
        font.pixelSize: 16
        activeFocusOnTab: false
        selectByMouse: true
        focus: false

        onTextChanged: {
            searchBar.onTextChanged(text)
        }

        Text {
            anchors.fill: parent
            verticalAlignment: Text.AlignVCenter
            color: "#88ffffff"
            font.pixelSize: 14
            text: "Type to filter windows..."
            visible: !searchInput.text || searchInput.text.length === 0
        }
    }
}
