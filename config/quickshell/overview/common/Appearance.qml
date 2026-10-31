pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import "functions"

Singleton {
    id: root
    property QtObject m3colors
    property QtObject animation
    property QtObject animationCurves
    property QtObject colors
    property QtObject rounding
    property QtObject font
    property QtObject sizes

    m3colors: QtObject {
        property bool darkmode: true
        property bool transparent: true

        // The palette wallust writes to qml_color.json, filled at startup by
        // MaterialThemeLoader. What is here is the fallback used until that
        // file has been read, so the panel is never uncoloured.
        property color m3windowBackground: "#111216"
        property color m3primaryText: "#EAE0E7"
        property color m3layerBackground1: ColorUtils.mix(m3primaryText, m3windowBackground, 0.05)
        property color m3layerBackground2: ColorUtils.mix(m3primaryText, m3windowBackground, 0.08)
        property color m3layerBackground3: ColorUtils.mix(m3primaryText, m3windowBackground, 0.12)
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

        // The Material 3 names the overview widgets were written against.
        // Derived from the roles above, so filling those moves both naming
        // schemes at once and nothing here needs the loader to know about it.
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

    colors: QtObject {
        property color colSubtext: m3colors.m3outline
        property color colLayer0: m3colors.m3background
        property color colOnLayer0: m3colors.m3onBackground
        property color colLayer0Border: ColorUtils.mix(root.m3colors.m3outlineVariant, colLayer0, 0.4)
        property color colLayer1: m3colors.m3surfaceContainerLow
        property color colOnLayer1: m3colors.m3onSurfaceVariant
        property color colOnLayer1Inactive: ColorUtils.mix(colOnLayer1, colLayer1, 0.45)
        property color colLayer1Hover: ColorUtils.mix(colLayer1, colOnLayer1, 0.92)
        property color colLayer1Active: ColorUtils.mix(colLayer1, colOnLayer1, 0.85)
        property color colLayer2: m3colors.m3surfaceContainer
        property color colOnLayer2: m3colors.m3onSurface
        property color colLayer2Hover: ColorUtils.mix(colLayer2, colOnLayer2, 0.90)
        property color colLayer2Active: ColorUtils.mix(colLayer2, colOnLayer2, 0.80)
        property color colPrimary: m3colors.m3primary
        property color colOnPrimary: m3colors.m3onPrimary
        property color colSecondary: m3colors.m3secondary
        property color colSecondaryContainer: m3colors.m3secondaryContainer
        property color colOnSecondaryContainer: m3colors.m3onSecondaryContainer
        property color colTooltip: m3colors.m3inverseSurface
        property color colOnTooltip: m3colors.m3inverseOnSurface
        property color colShadow: ColorUtils.transparentize(m3colors.m3shadow, 0.7)
        property color colOutline: m3colors.m3outline
    }

    rounding: QtObject {
        property int unsharpen: 2
        property int verysmall: 8
        property int small: 12
        property int normal: 17
        property int large: 23
        property int full: 9999
        property int screenRounding: large
        property int windowRounding: 18
    }

    font: QtObject {
        property QtObject family: QtObject {
            property string main: "sans-serif"
            property string title: "sans-serif"
            property string expressive: "sans-serif"
        }
        property QtObject pixelSize: QtObject {
            property int smaller: 12
            property int small: 15
            property int normal: 16
            property int larger: 19
            property int huge: 22
        }
    }

    animationCurves: QtObject {
        readonly property list<real> expressiveDefaultSpatial: [0.38, 1.21, 0.22, 1.00, 1, 1]
        readonly property list<real> expressiveEffects: [0.34, 0.80, 0.34, 1.00, 1, 1]
        readonly property list<real> emphasizedDecel: [0.05, 0.7, 0.1, 1, 1, 1]
        readonly property real expressiveDefaultSpatialDuration: 500
        readonly property real expressiveEffectsDuration: 200
    }

    animation: QtObject {
        property QtObject elementMove: QtObject {
            property int duration: animationCurves.expressiveDefaultSpatialDuration
            property int type: Easing.BezierSpline
            property list<real> bezierCurve: animationCurves.expressiveDefaultSpatial
            property Component numberAnimation: Component {
                NumberAnimation {
                    duration: root.animation.elementMove.duration
                    easing.type: root.animation.elementMove.type
                    easing.bezierCurve: root.animation.elementMove.bezierCurve
                }
            }
        }

        property QtObject elementMoveEnter: QtObject {
            property int duration: 400
            property int type: Easing.BezierSpline
            property list<real> bezierCurve: animationCurves.emphasizedDecel
            property Component numberAnimation: Component {
                NumberAnimation {
                    duration: root.animation.elementMoveEnter.duration
                    easing.type: root.animation.elementMoveEnter.type
                    easing.bezierCurve: root.animation.elementMoveEnter.bezierCurve
                }
            }
        }

        property QtObject elementMoveFast: QtObject {
            property int duration: animationCurves.expressiveEffectsDuration
            property int type: Easing.BezierSpline
            property list<real> bezierCurve: animationCurves.expressiveEffects
            property Component numberAnimation: Component {
                NumberAnimation {
                    duration: root.animation.elementMoveFast.duration
                    easing.type: root.animation.elementMoveFast.type
                    easing.bezierCurve: root.animation.elementMoveFast.bezierCurve
                }
            }
        }
    }

    sizes: QtObject {
        property real elevationMargin: 10
    }
}
