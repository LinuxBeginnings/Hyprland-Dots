// One row of the list: the chord as a row of caps, then its description.
//
// The chord column is a fixed width so descriptions line up down the list
// whatever the chord is - a two-cap chord and a four-cap chord put their text in
// the same place.
//
// Keysyms are translated to the short label a cap can carry. `XF86MonBrightnessUp`
// does not fit on a key, and neither does `asciicircum`, so both are mapped. The
// map is deliberately conservative: anything not listed is shown as written.

import QtQuick
import QtQuick.Layouts

Item {
    id: row

    property Theme theme
    property var entry: ({ chord: "", description: "", keys: [] })
    property bool selected: false
    property int chordColumnWidth: 208

    readonly property var modifiers: ["SUPER", "CTRL", "ALT", "SHIFT", "META", "MOD2", "MOD3", "MOD5"]

    implicitHeight: Math.max(caps.implicitHeight, descriptionText.implicitHeight) + 10

    // Short labels. Anything with a glyph uses one that is in Unicode rather
    // than a Nerd Font private-use code point, so a missing icon font cannot
    // turn a cap into a blank box.
    function keyLabel(key) {
        switch (key) {
        case "Return":
        case "Enter":
            return "⏎";
        case "SPACE":
            return "␣";
        case "Tab":
        case "tab":
            return "⇥";
        case "Delete":
        case "BackSpace":
            return "⌫";
        case "left":
            return "←";
        case "right":
            return "→";
        case "up":
            return "↑";
        case "down":
            return "↓";
        case "mouse_down":
            return "⇣";
        case "mouse_up":
            return "⇡";
        case "mouse:272":
            return "LMB";
        case "mouse:273":
            return "RMB";
        case "exclam":
            return "!";
        case "at":
            return "@";
        case "numbersign":
            return "#";
        case "dollar":
            return "$";
        case "percent":
            return "%";
        case "asciicircum":
            return "^";
        case "ampersand":
            return "&";
        case "asterisk":
            return "*";
        case "parenleft":
            return "(";
        case "parenright":
            return ")";
        case "bracketleft":
            return "[";
        case "bracketright":
            return "]";
        case "period":
            return ".";
        case "comma":
            return ",";
        case "equal":
            return "=";
        case "minus":
            return "-";
        case "KP_Add":
            return "Num+";
        case "KP_Subtract":
            return "Num-";
        case "Print":
            return "PrtSc";
        case "Shift_L":
        case "Shift_R":
            return "SHIFT";
        case "Alt_L":
        case "Alt_R":
            return "ALT";
        case "XF86AudioRaiseVolume":
            return "Vol+";
        case "XF86AudioLowerVolume":
            return "Vol-";
        case "XF86AudioMute":
            return "Mute";
        case "XF86AudioMicMute":
            return "Mic";
        case "XF86AudioPlay":
            return "Play";
        case "XF86AudioPause":
            return "Pause";
        case "XF86AudioNext":
            return "Next";
        case "XF86AudioPrev":
            return "Prev";
        case "XF86AudioStop":
            return "Stop";
        case "XF86MonBrightnessUp":
            return "Bright+";
        case "XF86MonBrightnessDown":
            return "Bright-";
        case "XF86KbdBrightnessUp":
            return "Kbd+";
        case "XF86KbdBrightnessDown":
            return "Kbd-";
        case "XF86KbdLightOnOff":
            return "Kbd";
        case "XF86TouchpadToggle":
            return "Touchpad";
        case "XF86Sleep":
            return "Sleep";
        case "XF86Rfkill":
            return "Airplane";
        case "XF86Display":
            return "Display";
        }
        // The lid switch is not a chord at all, so it gets the readable half.
        if (key.indexOf("switch:") === 0) return key.slice(7, 8).toUpperCase() + key.slice(8);
        return key;
    }

    Rectangle {
        anchors.fill: parent
        radius: 8
        color: row.selected ? row.theme.hover : "transparent"
        border.width: row.selected ? 1 : 0
        border.color: row.theme.border
    }

    RowLayout {
        id: caps

        anchors.left: parent.left
        anchors.leftMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        width: row.chordColumnWidth
        spacing: 5

        Repeater {
            model: row.entry.keys

            Keycap {
                required property var modelData

                theme: row.theme
                label: row.keyLabel(modelData)
                accent: row.modifiers.indexOf(modelData) !== -1
            }
        }
    }

    Text {
        id: descriptionText

        anchors.left: caps.right
        anchors.leftMargin: 6
        anchors.right: parent.right
        anchors.rightMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        text: row.entry.description
        // Brighter than `muted`: that role is mixed for secondary chrome, and a
        // description is the half of the row you actually read.
        color: row.selected ? row.theme.text
            : row.theme.mix(row.theme.bg, row.theme.text, 0.86)
        font.family: row.theme.fontFamily
        font.pixelSize: 12
        elide: Text.ElideRight
    }
}
