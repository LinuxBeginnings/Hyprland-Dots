pragma Singleton
import Quickshell

Singleton {
    id: root

    function doLayout(windowList, outerWidth, outerHeight) {
        var N = windowList.length
        if (N === 0) return []

        var gap = Math.max(8, outerWidth * 0.005)

        // Safe Area: We use slightly more width here (95%)
        // as vertical strips look better when filling the screen horizontally.
        var useW = outerWidth * 0.95
        var useH = outerHeight * 0.90
        var offX = (outerWidth - useW) / 2
        var offY = (outerHeight - useH) / 2

        // Calculate width of a single column
        var colW = (useW - (gap * (N - 1))) / N

        // Safety: If columns become too narrow (e.g. < 200px),
        // we clamp the width to keep them readable.
        var minColW = 200
        if (colW < minColW) colW = minColW

        // Calculate the actual total width used
        var totalW = N * colW + (N - 1) * gap

        // Center the group horizontally.
        // If N is small, it centers. If N is large (clamped), it starts from left.
        var startX = offX
        if (totalW < useW) {
            startX = offX + (useW - totalW) / 2
        }

        var result = []

        for (var i = 0; i < N; i++) {
            var item = windowList[i]

            var w0 = (item.width > 0) ? item.width : 100
            var h0 = (item.height > 0) ? item.height : 100

            // In this layout, vertical space is abundant (useH).
            // The constraining factor is usually the column width.
            var sc = Math.min(colW / w0, useH / h0)

            var thumbW = w0 * sc
            var thumbH = h0 * sc

            var xPos = startX + i * (colW + gap)

            // Center horizontally within the strip
            var xCentered = xPos + (colW - thumbW) / 2

            // Center vertically on screen
            var yCentered = offY + (useH - thumbH) / 2

            result.push({
                win: item.win,
                x: xCentered,
                y: yCentered,
                width: thumbW,
                height: thumbH
            })
        }

        return result
    }
}
