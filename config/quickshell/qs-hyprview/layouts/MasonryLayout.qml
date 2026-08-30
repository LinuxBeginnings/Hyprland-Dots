pragma Singleton
import Quickshell

Singleton {
    id: root

    function doLayout(windowList, outerWidth, outerHeight) {
        var N = windowList.length
        if (N === 0) return []

        // Gap: 0.8% of screen, clamped between 12px and 32px
        var rawGap = Math.min(outerWidth * 0.08, outerHeight * 0.08)
        var gap = Math.max(12, Math.min(32, rawGap))

        // Safe Area (90%)
        // Define the bounding box for the content.
        var contentScale = 0.90
        var useW = outerWidth * contentScale
        var useH = outerHeight * contentScale

        // Find Best Column Count
        // Standard logic: try to fit content in 1 col, then 2, etc.
        var bestCols = N

        for (var cols = 1; cols <= N; cols++) {
            var tryColWidth = (useW - (cols - 1) * gap) / cols
            var tryColHeights = new Array(cols).fill(0)

            for (var i = 0; i < N; i++) {
                var item = windowList[i]
                var minH = Math.min.apply(null, tryColHeights)
                var colIdx = tryColHeights.indexOf(minH)

                var w0 = (item.width && item.width > 0) ? item.width : 100
                var h0 = (item.height && item.height > 0) ? item.height : 100
                var scale = tryColWidth / w0

                tryColHeights[colIdx] += (h0 * scale) + gap
            }

            var currentMaxH = Math.max.apply(null, tryColHeights)
            if (currentMaxH > 0) currentMaxH -= gap

            // If it fits vertically, we stop.
            if (currentMaxH <= useH) {
                bestCols = cols
                break
            }
        }

        // Rigorous clamping
        // We have chosen 'bestCols'. Now we calculate the theoretical column width.
        // BUT, if N is small (e.g. 1), this width might produce a height > useH.
        // We must calculate a "Global Downscale Factor" to ensure NO item exceeds useH.

        var rawColWidth = (useW - (bestCols - 1) * gap) / bestCols
        var maxOverflowRatio = 1.0 // 1.0 means "fits perfectly"

        // Simulate again to find the worst offender (tallest item/column relative to screen)
        // Note: In masonry, we care about the total column height, not just single item.
        var clampHeights = new Array(bestCols).fill(0)

        for (var j = 0; j < N; j++) {
            var it = windowList[j]

            // Standard masonry placement logic
            var mH = Math.min.apply(null, clampHeights)
            var cId = clampHeights.indexOf(mH)

            var wRaw = (it.width && it.width > 0) ? it.width : 100
            var hRaw = (it.height && it.height > 0) ? it.height : 100
            var sc = rawColWidth / wRaw

            clampHeights[cId] += (hRaw * sc) + gap
        }

        // Find the tallest column produced by the raw width
        var tallestCol = Math.max.apply(null, clampHeights)
        if (tallestCol > 0) tallestCol -= gap

        // If the tallest column is taller than Safe Area, calculate reduction factor
        if (tallestCol > useH) {
            maxOverflowRatio = useH / tallestCol
        }

        // Apply the reduction factor to the column width.
        var finalColWidth = rawColWidth * maxOverflowRatio

        // Re-centering x
        var finalGridW = (finalColWidth * bestCols) + (gap * (bestCols - 1))
        var finalOffX = (outerWidth - finalGridW) / 2


        // Final rendering
        var colHeights = new Array(bestCols).fill(0)
        var result = []

        for (var k = 0; k < N; k++) {
            var itemK = windowList[k]

            // 1. Find shortest column
            var minH = Math.min.apply(null, colHeights)
            var cIdx = colHeights.indexOf(minH)

            // 2. Dimensions
            var wOrig = (itemK.width && itemK.width > 0) ? itemK.width : 100
            var hOrig = (itemK.height && itemK.height > 0) ? itemK.height : 100
            var s = finalColWidth / wOrig
            var tH = hOrig * s

            // 3. Position (using Recalculated OffX)
            var xPos = finalOffX + cIdx * (finalColWidth + gap)
            var yPos = colHeights[cIdx]

            result.push({
                win: itemK.win,
                x: xPos,
                y: yPos,
                width: finalColWidth,
                height: tH,
                colIndex: cIdx
            })

            colHeights[cIdx] += tH + gap
        }

        // Vertical centering
        var realGridH = Math.max.apply(null, colHeights)
        if (realGridH > 0) realGridH -= gap

        var finalOffY = (outerHeight - realGridH) / 2

        for (var m = 0; m < result.length; m++) {
            result[m].y += finalOffY
        }

        return result
    }
}
