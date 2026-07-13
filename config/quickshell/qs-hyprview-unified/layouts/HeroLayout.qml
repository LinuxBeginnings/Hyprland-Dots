pragma Singleton
import Quickshell
import Quickshell.Hyprland

Singleton {
    id: root

    function doLayout(windowList, outerWidth, outerHeight) {
        if (windowList.length === 0) return []

        // Gap: 0.8% of screen, clamped between 12px and 32px
        var rawGap = Math.min(outerWidth * 0.08, outerHeight * 0.08)
        var gap = Math.max(12, Math.min(32, rawGap))

        // Move active window to the head of windowList
        var activeAddr = Hyprland.activeToplevel?.lastIpcObject?.address
        if (activeAddr) {
            var activeIdx = windowList.findIndex(it => it.lastIpcObject.address === activeAddr)
            if (activeIdx !== -1) {
                windowList = [windowList[activeIdx], ...windowList.filter(it => it !== windowList[activeIdx])]
            }
        }

        // Safe area definition (90%)
        var contentScale = 0.90
        var useW = outerWidth * contentScale
        var useH = outerHeight * contentScale

        // Global offset - center Safe area
        var offX = (outerWidth - useW) / 2
        var offY = (outerHeight - useH) / 2

        var result = []

        // Screen zones (Hero/Stack)
        var heroRatio = 0.40 // 40% Hero
        var heroAreaW = useW * heroRatio
        var stackAreaW = useW - heroAreaW - gap // 60% Stack

        var heroItem = windowList[0]

        // Aspect Fit
        var hScale = Math.min(heroAreaW / heroItem.width, useH / heroItem.height)
        var hW = heroItem.width * hScale
        var hH = heroItem.height * hScale

        result.push({
            win: heroItem.win,
            x: offX + (heroAreaW - hW) / 2,
            y: offY + (useH - hH) / 2,
            width: hW,
            height: hH,
            isHero: true
        })

        var others = windowList.slice(1)
        var N = others.length

        if (N > 0) {
            var stackStartX = offX + heroAreaW + gap

            // Evaluate col number
            var bestCols = 1
            var bestRows = N

            // Windows height on a single column
            var oneColH = (useH - (gap * (N - 1))) / N

            // TOLERANCE THRESHOLD (0.15 = 15% of screen height)
            // If the windows are at least 15% of the screen height, we stay on 1 column.
            // With 4 windows we are at ~25% -> OK (1 Column)
            // With 7 windows we are at ~14% -> NO (Go to grid calculation)
            var useSingleCol = oneColH > (useH * 0.15)

            if (!useSingleCol) {
                // If space is limited, we look for the optimal grid starting with 2 columns.
                var bestScale = 0
                var TARGET_ASPECT = 16.0 / 9.0

                for (var cols = 2; cols <= N; cols++) {
                    var rows = Math.ceil(N / cols)
                    var availW = stackAreaW - (gap * (cols - 1))
                    var availH = useH - (gap * (rows - 1))

                    if (availW <= 0 || availH <= 0) continue

                    var cellW = availW / cols
                    var cellH = availH / rows

                    // Size score
                    var sW = cellW / TARGET_ASPECT
                    var sH = cellH / 1.0
                    var currentScale = Math.min(sW, sH)

                    if (currentScale > bestScale) {
                        bestScale = currentScale
                        bestCols = cols
                        bestRows = rows
                    }
                }
            }

            // Evaluation of the final dimensions of the selected grid
            var finalAvailW = stackAreaW - (gap * (bestCols - 1))
            var finalAvailH = useH - (gap * (bestRows - 1))

            var finalCellW = finalAvailW / bestCols
            var finalCellH = finalAvailH / bestRows

            // Vertical centering of the total stack
            var totalGridH = bestRows * finalCellH + (bestRows - 1) * gap
            var stackStartY = offY + (useH - totalGridH) / 2

            // Items positioning
            for (var i = 0; i < N; ++i) {
                var item = others[i]

                var row = Math.floor(i / bestCols)
                var col = i % bestCols

                // Cell coords (Standard Grid Alignment)
                // No “rowOffsetX”, cell 0 always starts on the left
                var cellAbsX = stackStartX + col * (finalCellW + gap)
                var cellAbsY = stackStartY + row * (finalCellH + gap)

                // Thumb aspect Fit
                var sc = Math.min(finalCellW / item.width, finalCellH / item.height)
                var w = item.width * sc
                var h = item.height * sc

                result.push({
                    win: item.win,
                    x: cellAbsX + (finalCellW - w) / 2,
                    y: cellAbsY + (finalCellH - h) / 2,
                    width: w,
                    height: h,
                    isHero: false
                })
            }
        }

        return result
    }
}
