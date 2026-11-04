pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

Singleton {
    id: root

    property QtObject m3colors: QtObject {
        property bool darkmode: true
        property bool transparent: true

        // The palette wallust writes to qml_color.json, filled at startup by
        // MaterialThemeLoader. What is here is the fallback used until that
        // file has been read, so the panel is never uncoloured.
        property color m3windowBackground: "#161217"
        property color m3primaryText: "#EAE0E7"
        property color m3layerBackground1: "#1F1A1F"
        property color m3layerBackground2: "#231E23"
        property color m3layerBackground3: "#2D282E"
        property color m3surfaceText: "#EAE0E7"
        property color m3secondaryText: "#CFC3CD"
        property color m3borderPrimary: "#cba6f7"
        property color m3shadowColor: "#000000"
        property color m3accentPrimary: "#E5B6F2"
        property color m3accentSecondary: "#D5C0D7"
        property color m3selectionBackground: "#534457"
        property color m3accentPrimaryText: "#452152"
        property color m3selectionText: "#F2DCF3"
        property color m3borderSecondary: "#4C444D"
        property color colTooltip: "#1e1e2e"
        property color colOnTooltip: "#F8F9FA"

        // The Material 3 names derived from the roles above
        property color m3primary: m3accentPrimary
        property color m3Primary: m3accentPrimary
        property color m3onPrimary: m3accentPrimaryText
        property color m3OnPrimary: m3accentPrimaryText
        property color m3primaryContainer: m3selectionBackground
        property color m3PrimaryContainer: m3selectionBackground
        property color m3onPrimaryContainer: m3selectionText
        property color m3OnPrimaryContainer: m3selectionText
        property color m3secondary: m3accentSecondary
        property color m3Secondary: m3accentSecondary
        property color m3onSecondary: m3selectionText
        property color m3OnSecondary: m3selectionText
        property color m3secondaryContainer: m3borderSecondary
        property color m3SecondaryContainer: m3borderSecondary
        property color m3onSecondaryContainer: m3surfaceText
        property color m3OnSecondaryContainer: m3surfaceText
        property color m3background: m3windowBackground
        property color m3onBackground: m3primaryText
        property color m3surface: m3windowBackground
        property color m3surfaceContainerLow: m3layerBackground1
        property color m3surfaceContainer: m3layerBackground2
        property color m3surfaceContainerHigh: m3layerBackground3
        property color m3surfaceContainerHighest: m3layerBackground3
        property color m3onSurface: m3surfaceText
        property color m3surfaceVariant: m3borderSecondary
        property color m3onSurfaceVariant: m3secondaryText
        property color m3inverseSurface: m3primaryText
        property color m3inverseOnSurface: m3windowBackground
        property color m3outline: m3secondaryText
        property color m3outlineVariant: m3borderSecondary
        property color m3shadow: m3shadowColor
    }
}
