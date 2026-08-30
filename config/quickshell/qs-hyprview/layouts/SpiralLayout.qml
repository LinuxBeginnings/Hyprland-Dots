pragma Singleton
import Quickshell
import Quickshell.Hyprland

Singleton {
    id: root

    function doLayout(windowList, outerWidth, outerHeight, maxSplits) {
        var N = windowList.length
        if (N === 0) return []

        if (maxSplits === undefined) maxSplits = 3

        // Standard Gap: 0.8% of screen
        var rawGap = outerWidth * 0.008
        var gap = Math.max(8, Math.min(24, rawGap))

        // Primary Gap: The space between the first Big Window and the rest.
        // We make it 3x larger than the standard gap for emphasis.
        var primaryGap = gap * 3

        // Safe Area (90%)
        var contentScale = 0.90
        var useW = outerWidth * contentScale
        var useH = outerHeight * contentScale
        var offX = (outerWidth - useW) / 2
        var offY = (outerHeight - useH) / 2

        // Move Active Window to start
        var activeAddr = Hyprland.activeToplevel?.lastIpcObject?.address
        if (activeAddr) {
            var activeIdx = windowList.findIndex(it => it.lastIpcObject.address === activeAddr)
            if (activeIdx !== -1) {
                windowList = [windowList[activeIdx], ...windowList.filter(it => it !== windowList[activeIdx])]
            }
        }

        var result = []

        // Working area cursor
        var curX = offX
        var curY = offY
        var curW = useW
        var curH = useH

        // Items to process in Spiral mode
        var spiralCount = Math.min(N - 1, maxSplits)

        // Spiral cuts
        for (var k = 0; k < spiralCount; k++) {
            var sItem = windowList[k]
            var sBoxW, sBoxH
            var sBoxX = curX
            var sBoxY = curY

            // Logic change: Use 'primaryGap' only for the very first cut (k=0),
            // otherwise use standard 'gap'.
            var currentGap = (k === 0) ? primaryGap : gap

            if (curW > curH) { // Split Vertical
                // Calculate width subtracting the specific gap for this iteration
                sBoxW = (curW - currentGap) / 2
                sBoxH = curH

                // Shift working area for next items by the specific gap
                curX += sBoxW + currentGap
                curW -= (sBoxW + currentGap)
            } else { // Split Horizontal
                sBoxW = curW
                sBoxH = (curH - currentGap) / 2

                // Shift working area for next items by the specific gap
                curY += sBoxH + currentGap
                curH -= (sBoxH + currentGap)
            }

            // Aspect Fit
            var sw0 = (sItem.width > 0) ? sItem.width : 100
            var sh0 = (sItem.height > 0) ? sItem.height : 100
            var sScale = Math.min(sBoxW / sw0, sBoxH / sh0)

            result.push({
                win: sItem.win,
                x: sBoxX + (sBoxW - (sw0 * sScale))/2,
                y: sBoxY + (sBoxH - (sh0 * sScale))/2,
                width: sw0 * sScale,
                height: sh0 * sScale,
                isSpiral: true,
                index: k
            })
        }

        // Overflow grid
        var remainingItems = windowList.slice(spiralCount)
        var remN = remainingItems.length

        if (remN > 0) {
            // Standard Grid logic for the remaining box
            var bestCols = 1
            var bestScale = 0
            var TARGET_ASPECT = 16.0/9.0

            for (var c = 1; c <= remN; c++) {
                var r = Math.ceil(remN / c)
                var avW = curW - gap * (c - 1)
                var avH = curH - gap * (r - 1)
                if (avW <= 0 || avH <= 0) continue

                var cW = avW / c
                var cH = avH / r
                var sc = Math.min(cW / TARGET_ASPECT, cH)

                if (sc > bestScale) {
                    bestScale = sc
                    bestCols = c
                }
            }

            var remRows = Math.ceil(remN / bestCols)
            var finalCellW = (curW - gap * (bestCols - 1)) / bestCols
            var finalCellH = (curH - gap * (remRows - 1)) / remRows

            var gridContentH = remRows * finalCellH + (remRows - 1) * gap
            var gridStartY = curY + (curH - gridContentH) / 2

            for (var j = 0; j < remN; j++) {
                var rItem = remainingItems[j]
                var row = Math.floor(j / bestCols)
                var col = j % bestCols

                var itemsInRow = Math.min((row + 1) * bestCols, remN) - (row * bestCols)
                var rowW = itemsInRow * finalCellW + (itemsInRow - 1) * gap
                var rowStartX = curX + (curW - rowW) / 2

                var cellX = rowStartX + col * (finalCellW + gap)
                var cellY = gridStartY + row * (finalCellH + gap)

                var rw0 = (rItem.width > 0) ? rItem.width : 100
                var rh0 = (rItem.height > 0) ? rItem.height : 100
                var rSc = Math.min(finalCellW / rw0, finalCellH / rh0)

                result.push({
                    win: rItem.win,
                    x: cellX + (finalCellW - (rw0 * rSc))/2,
                    y: cellY + (finalCellH - (rh0 * rSc))/2,
                    width: rw0 * rSc,
                    height: rh0 * rSc,
                    isSpiral: false
                })
            }
        }

        return result
    }
}
