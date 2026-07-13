import QtQuick
import QtQuick.Effects
import ".."

RectangularShadow {
    anchors.fill: target
    radius: 20
    blur: 0.9 * Appearance.sizes.elevationMargin
    offset: Qt.vector2d(0.0, 1.0)
    spread: 1
    color: Appearance.colors.colShadow
    cached: true
}
