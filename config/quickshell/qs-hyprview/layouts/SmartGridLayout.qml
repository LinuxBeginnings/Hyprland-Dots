pragma Singleton
import Quickshell

Singleton {
    id: root

    function doLayout(windowList, outerWidth, outerHeight) {
        var N = windowList.length
        if (N === 0) return []
        if (outerWidth <= 0 || outerHeight <= 0) return []

        var gap = Math.min(outerWidth * 0.03, outerHeight * 0.03)

        // --- 0. DEFINIZIONE AREA SICURA (SCALATA) ---
        // Riduciamo l'area di calcolo al 90% per lasciare spazio alle animazioni hover
        var contentScale = 0.9
        var usableW = outerWidth * contentScale
        var usableH = outerHeight * contentScale

        // --- 1. TROVARE LA SCALA OTTIMALE ---
        // Usiamo usableW/H per decidere la dimensione delle finestre
        var TARGET_ASPECT = 16.0 / 9.0
        var bestCols = 1
        var bestRows = 1
        var bestScale = 0

        for (var cols = 1; cols <= N; cols++) {
            var rows = Math.ceil(N / cols)

            // Calcoliamo lo spazio basandoci sull'area ridotta
            var availW = usableW - gap * (cols - 1)
            var availH = usableH - gap * (rows - 1)

            if (availW <= 0 || availH <= 0) continue

            var cellW = availW / cols
            var cellH = availH / rows

            var scaleW = cellW / TARGET_ASPECT
            var scaleH = cellH / 1.0
            var currentScale = Math.min(scaleW, scaleH)

            if (currentScale > bestScale) {
                bestScale = currentScale
                bestCols = cols
                bestRows = rows
            }
        }

        // --- 2. CALCOLO DIMENSIONI REALI ---

        // Ricalcoliamo i limiti cella basati sull'area ridotta
        var finalAvailW = usableW - gap * (bestCols - 1)
        var finalAvailH = usableH - gap * (bestRows - 1)
        var maxCellW = finalAvailW / bestCols
        var maxCellH = finalAvailH / bestRows

        // --- 3. POSIZIONAMENTO (CENTRATO NELL'AREA TOTALE) ---

        // Calcoliamo l'altezza totale del blocco di contenuto
        var totalGridContentH = bestRows * maxCellH + (bestRows - 1) * gap

        // Per centrare verticalmente, usiamo l'outerHeight REALE (al 100%)
        // In questo modo il blocco ridotto (90%) finisce esattamente al centro dello schermo fisico
        var startOffsetY = (outerHeight - totalGridContentH) / 2

        var result = []

        // Iteriamo per RIGA
        for (var r = 0; r < bestRows; r++) {
            var rowItems = []
            var startIndex = r * bestCols
            var endIndex = Math.min(startIndex + bestCols, N)

            if (startIndex >= N) break

            var totalRowContentWidth = 0

            // Fase 3a: Calcolo dimensioni miniature (Packed)
            for (var i = startIndex; i < endIndex; i++) {
                var item = windowList[i]
                var w0 = (item.width && item.width > 0) ? item.width : 100
                var h0 = (item.height && item.height > 0) ? item.height : 100

                // Scala calcolata sui limiti "sicuri" (90%)
                var scale = Math.min(maxCellW / w0, maxCellH / h0)

                var thumbW = w0 * scale
                var thumbH = h0 * scale

                rowItems.push({
                    originalItem: item,
                    width: thumbW,
                    height: thumbH,
                    index: i,
                    col: i - startIndex
                })

                totalRowContentWidth += thumbW
            }

            // Aggiungiamo i gap totali della riga
            if (rowItems.length > 1) {
                totalRowContentWidth += (rowItems.length - 1) * gap
            }

            // Fase 3b: Posizionamento X
            // Anche qui, usiamo outerWidth REALE per centrare il blocco riga nello schermo intero
            var currentX = (outerWidth - totalRowContentWidth) / 2
            var cellAbsY = startOffsetY + r * (maxCellH + gap)

            for (var k = 0; k < rowItems.length; k++) {
                var rItem = rowItems[k]

                // Centratura verticale nella fascia
                var currentY = cellAbsY + (maxCellH - rItem.height) / 2

                result.push({
                    win: rItem.originalItem.win,
                    x: currentX,
                    y: currentY,
                    width: rItem.width,
                    height: rItem.height,
                    rowIndex: r,
                    colIndex: rItem.col
                })

                currentX += rItem.width + gap
            }
        }

        return result
    }
}
