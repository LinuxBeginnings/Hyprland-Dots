pragma Singleton
import Quickshell

Singleton {
    id: root

    function doLayout(windowList, outerWidth, outerHeight) {
        var N = windowList.length
        if (N === 0) return []

        var gap = Math.max(10, outerWidth * 0.01)

        // Safe Area
        var useW = outerWidth * 0.9
        var useH = outerHeight * 0.9
        var offX = (outerWidth - useW) / 2
        var offY = (outerHeight - useH) / 2

        // Heuristic: roughly sqrt(N), but slightly weighted towards columns
        // to accommodate 16:9 screens better.
        var cols = Math.ceil(Math.sqrt(N * 1.5))
        var rows = Math.ceil(N / cols)

        // Calculate cell width.
        // Note: In a staggered layout, the effective width needed is (cols + 0.5)
        // because alternate rows are shifted by half a cell.
        var cellW = (useW - (cols * gap)) / (cols + 0.5)
        var cellH = (useH - (rows * gap)) / rows

        // Vertical centering of the whole block
        var contentH = rows * cellH + (rows - 1) * gap
        var startY = offY + (useH - contentH) / 2

        var result = []

        for (var i = 0; i < N; i++) {
            var item = windowList[i]

            var r = Math.floor(i / cols)
            var c = i % cols

            // Stagger offset: if row is odd, shift right by half cell width
            var staggerOffset = (r % 2 === 1) ? (cellW / 2) : 0

            var cellX = staggerOffset + c * (cellW + gap)
            var cellY = r * (cellH + gap)

            // Aspect Fit
            var w0 = (item.width > 0) ? item.width : 100
            var h0 = (item.height > 0) ? item.height : 100
            var sc = Math.min(cellW / w0, cellH / h0)

            // Center the thumbnail inside the calculated cell
            result.push({
                win: item.win,
                x: offX + cellX + (cellW - w0 * sc)/2,
                y: startY + cellY + (cellH - h0 * sc)/2,
                width: w0 * sc,
                height: h0 * sc
            })
        }
        return result
    }
}
