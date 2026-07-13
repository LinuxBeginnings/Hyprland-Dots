import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import Quickshell.Wayland
import Quickshell.Hyprland
import Qt5Compat.GraphicalEffects
import "../layouts"
import "."

PanelWindow {
    id: root

    // --- SETTINGS ---
    property string layoutAlgorithm: ""
    property string lastLayoutAlgorithm: ""
    property bool liveCapture: false
    property bool moveCursorToActiveWindow: false

    // --- INTERNAL STATE ---
    property bool isActive: false
    property bool specialActive: false
    property bool animateWindows: false
    property var lastPositions: {}
    property real backdropOpacity: 0.2

    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    visible: isActive

    // LayerShell Configs
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.exclusiveZone: -1
    WlrLayershell.keyboardFocus: isActive ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    WlrLayershell.namespace: "quickshell:expose"

    Timer {
        id: searchFocusTimer
        interval: 25
        repeat: false
        onTriggered: {
            if (root.isActive) {
                searchBox.focusInput()
            }
        }
    }

    // --- IPC & EVENTS ---
    IpcHandler {
        target: "expose"
        function toggle(layout: string) {
            root.layoutAlgorithm = layout
            root.toggleExpose()
        }

        function open(layout: string) {
            root.layoutAlgorithm = layout
            if (root.isActive) return
            root.toggleExpose()
        }

        function close() {
            if (!root.isActive) return
            root.toggleExpose()
        }
    }

    Connections {
        target: Hyprland
        function onRawEvent(ev) {
            if (!root.isActive && ev.name !== "activespecial") return

            switch (ev.name) {
                case "openwindow":
                case "closewindow":
                case "changefloatingmode":
                case "movewindow":
                Hyprland.refreshToplevels()
                refreshThumbs()
                return

                case "activespecial":
                var dataStr = String(ev.data)
                var namePart = dataStr.split(",")[0]
                root.specialActive = (namePart.length > 0)
                return

                default:
                return
            }
        }
    }

    // Update thumbs every 125ms if liveCapture = false
    Timer {
        id: screencopyTimer
        interval: 125
        repeat: true
        running: !root.liveCapture && root.isActive
        onTriggered: root.refreshThumbs()
    }


    function toggleExpose() {
        root.isActive = !root.isActive
        if (root.isActive) {
            if (root.layoutAlgorithm === 'random') {
                var layouts = [
                    'smartgrid',
                    'justified',
                    'bands',
                    'masonry',
                    'hero',
                    'spiral',
                    'satellite',
                    'staggered',
                    'columnar',
                    'vortex',
                ].filter((l) => l !== root.lastLayoutAlgorithm)
                var randomLayout = layouts[Math.floor(Math.random() * layouts.length)]
                root.lastLayoutAlgorithm = randomLayout
            } else {
                root.lastLayoutAlgorithm = root.layoutAlgorithm
            }

            exposeArea.currentIndex = -1
            searchBox.reset()
            Hyprland.refreshToplevels()
            refreshThumbs()
            searchFocusTimer.restart()
        } else {
            root.animateWindows = false
            root.lastPositions = {}
            searchFocusTimer.stop()
            searchBox.releaseInputFocus()
        }
    }

    function refreshThumbs() {
        if (!root.isActive) return
        for (var i = 0; i < winRepeater.count; ++i) {
            var it = winRepeater.itemAt(i)
            if (it && it.visible && it.refreshThumb) {
                it.refreshThumb()
            }
        }
    }

    // --- USER INTERFACE ---
    FocusScope {
        id: mainScope
        anchors.fill: parent
        focus: true

        Rectangle {
            anchors.fill: parent
            color: "#000000"
            opacity: root.isActive ? root.backdropOpacity : 0
            visible: root.isActive && root.backdropOpacity > 0
            z: -2
        }

        Keys.onPressed: (event) => {
            if (!root.isActive) return

            if (event.key === Qt.Key_Escape) {
                root.toggleExpose()
                event.accepted = true
                return
            }

            const total = winRepeater.count
            if (total <= 0) return

            // Helper for horizontal navigation
            function moveSelectionHorizontal(delta) {
                var start = exposeArea.currentIndex
                for (var step = 1; step <= total; ++step) {
                    var candidate = (start + delta * step + total) % total
                    var it = winRepeater.itemAt(candidate)
                    if (it && it.visible) {
                        exposeArea.currentIndex = candidate
                        return
                    }
                }
            }

            // Helper for vertical navigation
            function moveSelectionVertical(dir) {
                var startIndex = exposeArea.currentIndex
                var currentItem = winRepeater.itemAt(startIndex)

                if (!currentItem || !currentItem.visible) {
                    moveSelectionHorizontal(dir > 0 ? 1 : -1)
                    return
                }

                var curCx = currentItem.x + currentItem.width  / 2
                var curCy = currentItem.y + currentItem.height / 2

                var bestIndex = -1
                var bestDy = 99999999
                var bestDx = 99999999

                for (var i = 0; i < total; ++i) {
                    var it = winRepeater.itemAt(i)
                    if (!it || !it.visible || i === startIndex) continue

                    var cx = it.x + it.width  / 2
                    var cy = it.y + it.height / 2
                    var dy = cy - curCy

                    // Direction filtering
                    if (dir > 0 && dy <= 0) continue
                    if (dir < 0 && dy >= 0) continue

                    var absDy = Math.abs(dy)
                    var absDx = Math.abs(cx - curCx)

                    // Search for nearest thumb (first in vertical, then horizontal distance)
                    if (absDy < bestDy || (absDy === bestDy && absDx < bestDx)) {
                        bestDy = absDy
                        bestDx = absDx
                        bestIndex = i
                    }
                }

                if (bestIndex >= 0) {
                    exposeArea.currentIndex = bestIndex
                }
            }

            // --- NVIM-style navigation with Ctrl ---
            const ctrl = event.modifiers & Qt.ControlModifier

            if (ctrl) {
                if (event.key === Qt.Key_L) {
                    moveSelectionHorizontal(1)
                    event.accepted = true
                } else if (event.key === Qt.Key_H) {
                    moveSelectionHorizontal(-1)
                    event.accepted = true
                } else if (event.key === Qt.Key_J) {
                    moveSelectionVertical(1)
                    event.accepted = true
                } else if (event.key === Qt.Key_K) {
                    moveSelectionVertical(-1)
                    event.accepted = true
                }
                return
            }

            if (event.key === Qt.Key_Right || event.key === Qt.Key_Tab) {
                moveSelectionHorizontal(1)
                event.accepted = true
            } else if (event.key === Qt.Key_Left || event.key === Qt.Key_Backtab) {
                moveSelectionHorizontal(-1)
                event.accepted = true
            } else if (event.key === Qt.Key_Down) {
                moveSelectionVertical(1)
                event.accepted = true
            } else if (event.key === Qt.Key_Up) {
                moveSelectionVertical(-1)
                event.accepted = true
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                var item = winRepeater.itemAt(exposeArea.currentIndex)
                if (item && item.activateWindow) {
                    item.activateWindow()
                    event.accepted = true
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: false
            z: -1
            onClicked: root.toggleExpose()
        }

        Item {
            id: layoutContainer
            anchors.fill: parent
            anchors.margins: 32

            Column {
                id: layoutRoot
                anchors.fill: parent
                anchors.margins: 48
                spacing: 20

                // thumbs area
                Item {
                    id: exposeArea
                    width: layoutRoot.width
                    height: layoutRoot.height - searchBox.implicitHeight - layoutRoot.spacing

                    property int currentIndex: 0
                    property string searchText: ""

                    // Reset active thumb on searchText change
                    onSearchTextChanged: {
                        currentIndex = (windowLayoutModel.count > 0) ? 0 : -1
                    }

                    ScriptModel {
                        id: windowLayoutModel

                        property int areaW: exposeArea.width
                        property int areaH: exposeArea.height
                        property string query: exposeArea.searchText
                        property string algo: root.lastLayoutAlgorithm
                        property var rawToplevels: Hyprland.toplevels.values

                        values: {
                            // Bailout on wrong screen size
                            if (areaW <= 0 || areaH <= 0) return []

                            var q = (query || "").toLowerCase()
                            var windowList = []
                            var idx = 0

                            if (!rawToplevels) return []

                            for (var it of rawToplevels) {
                                var w = it
                                var clientInfo = w && w.lastIpcObject ? w.lastIpcObject : {}
                                var workspace = clientInfo && clientInfo.workspace ? clientInfo.workspace : null
                                var workspaceId = workspace && workspace.id !== undefined ? workspace.id : undefined

                                // Filter invalid workspace or offscreen windows
                                if (workspaceId === undefined || workspaceId === null) continue
                                var size = clientInfo && clientInfo.size ? clientInfo.size : [0, 0]
                                var at = clientInfo && clientInfo.at ? clientInfo.at : [-1000, -1000]
                                if (at[1] + size[1] <= 0) continue

                                // Text filtering
                                var title = (w.title || clientInfo.title || "").toLowerCase()
                                var clazz = (clientInfo["class"] || "").toLowerCase()
                                var ic = (clientInfo.initialClass || "").toLowerCase()
                                var app = (w.appId || clientInfo.initialClass || "").toLowerCase()

                                if (q.length > 0) {
                                    var match = title.indexOf(q) !== -1 || clazz.indexOf(q) !== -1 ||
                                    ic.indexOf(q) !== -1 || app.indexOf(q) !== -1
                                    if (!match) continue
                                }

                                windowList.push({
                                    win: w,
                                    clientInfo: clientInfo,
                                    workspaceId: workspaceId,
                                    width: size[0],
                                    height: size[1],
                                    originalIndex: idx++,
                                    lastIpcObject: w.lastIpcObject
                                })
                            }

                            // Sort by workspaceId, then originalIndex
                            windowList.sort(function(a, b) {
                                if (a.workspaceId < b.workspaceId) return -1
                                if (a.workspaceId > b.workspaceId) return 1
                                if (a.originalIndex < b.originalIndex) return -1
                                if (a.originalIndex > b.originalIndex) return 1
                                return 0
                            })

                            return LayoutsManager.doLayout(algo, windowList, areaW, areaH)
                        }
                    }

                    Repeater {
                        id: winRepeater
                        model: windowLayoutModel

                        delegate: WindowThumbnail {
                            // Model data
                            hWin: modelData.win
                            wHandle: hWin.wayland
                            winKey: String(hWin.address)
                            thumbW: modelData.width
                            thumbH: modelData.height
                            clientInfo: hWin.lastIpcObject

                            // Layout-generated coordinates
                            targetX: modelData.x
                            targetY: modelData.y
                            targetZ: (visible && (exposeArea.currentIndex === index)) ? 1000: modelData.zIndex || 0
                            targetRotation: modelData.rotation || 0

                            hovered: visible && (exposeArea.currentIndex === index)
                            moveCursorToActiveWindow: root.moveCursorToActiveWindow
                        }
                    }
                }

                SearchBox {
                    id: searchBox
                    onTextChanged: function(text) {
                        root.animateWindows = true
                        exposeArea.searchText = text
                    }
                }
            }
        }
    }
}
