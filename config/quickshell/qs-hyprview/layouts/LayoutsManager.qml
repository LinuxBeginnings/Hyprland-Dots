pragma Singleton
import Quickshell
import "."

Singleton {
    id: root

    function doLayout( layoutAlgorithm, windowList, width, height) {
        var doLayout = null
        switch (layoutAlgorithm) {
            case 'smartgrid':
                doLayout = SmartGridLayout.doLayout
                break
            case 'justified':
                doLayout = JustifiedLayout.doLayout
                break
            case 'bands':
                doLayout = BandsLayout.doLayout
                break
            case 'masonry':
                doLayout = MasonryLayout.doLayout
                break
            case 'hero':
                doLayout = HeroLayout.doLayout
                break
            case 'spiral':
                doLayout = SpiralLayout.doLayout
                break
            case 'satellite':
                doLayout = SatelliteLayout.doLayout
                break
            case 'staggered':
                doLayout = StarggeredLayout.doLayout
                break
            case 'columnar':
                doLayout = ColumnarLayout.doLayout
                break
            case 'vortex':
                doLayout = VortexLayout.doLayout
                break
            default:
                doLayout = SmartGridLayout.doLayout
        }

        return doLayout( windowList, width, height)
    }
}
