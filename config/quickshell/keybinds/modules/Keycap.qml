// One key cap, drawn rather than imported.
//
// Three stacked rectangles do the work, which is what makes a cap read as a
// physical key instead of a labelled box:
//   * a side face, offset down by `depth`, darker than the top: the thickness;
//   * the top face, with a vertical gradient that is lighter at the top edge;
//   * a hairline highlight just inside the top edge, which the eye reads as the
//     rounded bevel of a key top.
//
// No image assets, so the caps follow the wallpaper palette like the rest of the
// panel and stay sharp at any size or scale.

import QtQuick

Item {
    id: cap

    property Theme theme
    property string label: ""
    // Modifiers are tinted with the palette accent, so which key you hold is
    // readable at a glance in a four-cap chord.
    property bool accent: false

    readonly property real depth: 3
    readonly property real faceHeight: 26
    readonly property real radius: 7

    readonly property color faceTop: accent
        ? theme.mix(theme.accent, "#ffffff", 0.30)
        : theme.mix(theme.bg, theme.text, 0.20)
    readonly property color faceBottom: accent
        ? theme.mix(theme.accent, "#000000", 0.10)
        : theme.mix(theme.bg, theme.text, 0.08)
    readonly property color sideColor: accent
        ? theme.mix(theme.accent, "#000000", 0.55)
        : theme.mix(theme.bg, "#000000", 0.30)
    readonly property color edgeColor: accent
        ? theme.mix(theme.accent, "#ffffff", 0.55)
        : theme.mix(theme.bg, theme.text, 0.34)
    readonly property color inkColor: accent ? theme.accentInk : theme.text

    implicitWidth: Math.max(30, capLabel.implicitWidth + 16)
    implicitHeight: faceHeight + depth

    // Side face: the visible thickness of the cap.
    Rectangle {
        x: 0
        y: cap.depth
        width: cap.width
        height: cap.faceHeight
        radius: cap.radius
        color: cap.sideColor
    }

    // Top face.
    Rectangle {
        id: topFace

        x: 0
        y: 0
        width: cap.width
        height: cap.faceHeight
        radius: cap.radius
        border.width: 1
        border.color: cap.edgeColor

        gradient: Gradient {
            GradientStop {
                position: 0.0
                color: cap.faceTop
            }
            GradientStop {
                position: 1.0
                color: cap.faceBottom
            }
        }

        Rectangle {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.topMargin: 2
            anchors.leftMargin: 3
            anchors.rightMargin: 3
            height: 1
            color: "#ffffff"
            opacity: cap.accent ? 0.35 : 0.14
        }

        Text {
            id: capLabel

            anchors.centerIn: parent
            text: cap.label
            color: cap.inkColor
            font.family: cap.theme.fontFamily
            font.pixelSize: 11
            font.bold: true
        }
    }
}
