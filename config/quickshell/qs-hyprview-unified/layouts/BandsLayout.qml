pragma Singleton
import Quickshell

Singleton {
    id: root

    function doLayout(windowList, outerWidth, outerHeight) {
        var N = windowList.length
        if (N === 0) return []

        // Gap: 0.8% of screen, clamped between 12px and 24px
        var rawGap = Math.min(outerWidth * 0.08, outerHeight * 0.08)
        var gap = Math.max(12, Math.min(24, rawGap))

        // Safe Area: 90% of the screen
        var contentScale = 0.90
        var useW = outerWidth * contentScale
        var useH = outerHeight * contentScale

        // Global offsets to center everything
        var offX = (outerWidth - useW) / 2
        var offY = (outerHeight - useH) / 2

        // Group by workspace
        var groups = {}
        var wsOrder = []

        for (var i = 0; i < N; i++) {
            var w = windowList[i]
            var wsId = w.workspaceId

            if (!groups[wsId]) {
                groups[wsId] = []
                wsOrder.push(wsId)
            }
            groups[wsId].push(w)
        }

        var bandCount = wsOrder.length
        if (bandCount === 0) return []

        // Band height & max thumb height

        // Calculate the height allocated for each workspace band
        var totalGapH = gap * (bandCount - 1)
        var bandHeight = (useH - totalGapH) / bandCount

        // Aesthetic Cap: Even if we have only 1 workspace,
        // windows shouldn't exceed 45% of screen height.
        var absoluteMaxH = useH * 0.45

        // The effective max height is the smaller of the two.
        // If we have 10 bands, bandHeight will be small (e.g. 100px), so that rules.
        // If we have 1 band, bandHeight is huge (1000px), so absoluteMaxH (450px) rules.
        var localMaxH = Math.min(bandHeight, absoluteMaxH)

        // Minimum safety height to avoid division by zero errors
        if (localMaxH < 10) localMaxH = 10

        var result = []
        var currentY = offY

        // Process each band
        for (var b = 0; b < bandCount; b++) {
            var wsId = wsOrder[b]
            var items = groups[wsId]
            var itemCount = items.length

            // ROW LAYOUT CALCULATION (Justified)
            var rows = []
            var currentRow = []
            var currentAspectSum = 0

            for (var k = 0; k < itemCount; k++) {
                var item = items[k]
                var w0 = (item.width > 0) ? item.width : 100
                var h0 = (item.height > 0) ? item.height : 100
                var aspect = w0 / h0

                var wrapper = { win: item.win, aspect: aspect }

                // Check overflow: (SumAspects * MaxH) + Gaps > Width
                var hypotheticalWidth = (currentAspectSum + aspect) * localMaxH + (currentRow.length * gap)

                if (currentRow.length > 0 && hypotheticalWidth > useW) {
                    rows.push({ items: currentRow, aspectSum: currentAspectSum })
                    currentRow = []
                    currentAspectSum = 0
                }

                currentRow.push(wrapper)
                currentAspectSum += aspect
            }
            if (currentRow.length > 0) {
                rows.push({ items: currentRow, aspectSum: currentAspectSum })
            }

            // SCALE & FIT ROWS
            // Calculate how tall the content actually is
            var totalContentH = 0
            var finalRows = []

            for (var r = 0; r < rows.length; r++) {
                var rowObj = rows[r]
                var rItems = rowObj.items

                // Optimal Height = (Available Width / Sum Aspects)
                var availRowW = useW - (gap * (rItems.length - 1))
                var optimalH = availRowW / rowObj.aspectSum

                // Clamp to limits
                if (optimalH > localMaxH) optimalH = localMaxH

                finalRows.push({ items: rItems, h: optimalH })
                totalContentH += optimalH
            }

            // Add vertical gaps between rows inside the band
            if (finalRows.length > 1) {
                totalContentH += gap * (finalRows.length - 1)
            }

            // If rows overflow the band height (rare, but possible with many windows), scale down
            var scaleFactor = 1.0
            if (totalContentH > bandHeight) {
                scaleFactor = bandHeight / totalContentH
                totalContentH = bandHeight // Cap for centering math
            }

            // GENERATE COORDINATES
            // Center the content vertically within the band slot
            // Note: If bandCount=1, bandHeight is huge (90% screen), but totalContentH is constrained by absoluteMaxH.
            // This ensures the single row floats nicely in the middle.
            var rowY = currentY + (bandHeight - totalContentH) / 2

            for (var r2 = 0; r2 < finalRows.length; r2++) {
                var fRow = finalRows[r2]
                var rHeight = fRow.h * scaleFactor
                var rItems2 = fRow.items

                // Calculate row width for horizontal centering
                var actualRowW = 0
                for (var j = 0; j < rItems2.length; j++) {
                    actualRowW += (rItems2[j].aspect * rHeight)
                }
                actualRowW += gap * (rItems2.length - 1)

                var rowX = offX + (useW - actualRowW) / 2

                for (var j2 = 0; j2 < rItems2.length; j2++) {
                    var it = rItems2[j2]
                    var finalW = it.aspect * rHeight

                    result.push({
                        win: it.win,
                        x: rowX,
                        y: rowY,
                        width: finalW,
                        height: rHeight
                    })

                    rowX += finalW + gap
                }

                rowY += rHeight + (gap * scaleFactor)
            }

            // Advance Y to the next band slot
            currentY += bandHeight + gap
        }

        return result
    }
}
