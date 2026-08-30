pragma Singleton
import Quickshell
import Quickshell.Hyprland

Singleton {
    id: root

    function doLayout(windowList, outerWidth, outerHeight) {
        var N = windowList.length
        if (N === 0) return []

        // Move active window to the start of the list (Center Item)
        var activeAddr = Hyprland.activeToplevel?.lastIpcObject?.address
        if (activeAddr) {
            var activeIdx = windowList.findIndex(it => it.lastIpcObject.address === activeAddr)
            if (activeIdx !== -1) {
                windowList = [windowList[activeIdx], ...windowList.filter(it => it !== windowList[activeIdx])]
            }
        }

        // Safe Area definition (90%)
        var useW = outerWidth * 0.90
        var useH = outerHeight * 0.90
        var offX = (outerWidth - useW) / 2
        var offY = (outerHeight - useH) / 2

        var result = []

        // Center item (hero)
        var centerItem = windowList[0]

        // The center item takes up roughly 35% of the screen dimensions
        var centerW = useW * 0.35
        var centerH = useH * 0.35

        // Aspect Fit for the center item
        var w0 = (centerItem.width > 0) ? centerItem.width : 100
        var h0 = (centerItem.height > 0) ? centerItem.height : 100
        var sc0 = Math.min(centerW / w0, centerH / h0)
        var finalCenterW = w0 * sc0
        var finalCenterH = h0 * sc0

        result.push({
            win: centerItem.win,
            x: offX + (useW - finalCenterW) / 2,
            y: offY + (useH - finalCenterH) / 2,
            width: finalCenterW,
            height: finalCenterH,
            isSatellite: false
        })

        // Orbit items (satellites)
        var satellites = windowList.slice(1)
        var numSat = satellites.length

        if (numSat > 0) {
            // Orbit Radius (distance from center)
            var radiusX = useW * 0.4
            var radiusY = useH * 0.4

            // Max size for satellites.
            // As the number of satellites increases, we shrink them to avoid overlap.
            var maxSatW = (useW * 0.25) / Math.max(1, (numSat / 6))
            var maxSatH = (useH * 0.25) / Math.max(1, (numSat / 6))

            // Start angle (-90 degrees = Top)
            var startAngle = -Math.PI / 2
            var stepAngle = (2 * Math.PI) / numSat

            for (var i = 0; i < numSat; i++) {
                var item = satellites[i]
                var angle = startAngle + (i * stepAngle)

                // Calculate satellite center coordinates
                var cx = (useW / 2) + radiusX * Math.cos(angle)
                var cy = (useH / 2) + radiusY * Math.sin(angle)

                // Aspect Fit satellite
                var ws = (item.width > 0) ? item.width : 100
                var hs = (item.height > 0) ? item.height : 100
                var scS = Math.min(maxSatW / ws, maxSatH / hs)
                var finalSatW = ws * scS
                var finalSatH = hs * scS

                result.push({
                    win: item.win,
                    x: offX + cx - (finalSatW / 2),
                    y: offY + cy - (finalSatH / 2),
                    width: finalSatW,
                    height: finalSatH,
                    isSatellite: true
                })
            }
        }

        return result
    }
}
