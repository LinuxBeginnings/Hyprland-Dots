// The carousel: a frameless deck of portrait wallpaper cards fanned across the
// monitor, tallest in the middle and shrinking towards both edges, with a search
// bar and the name of the focused card underneath.
//
// There is no panel behind the deck: the window is transparent and only the
// cards and the search bar are drawn, so the wallpaper stays visible around them
// and the deck reads as floating. Clicking the deck's empty space, Escape or
// applying a wallpaper closes it; clicking outside the strip goes to the
// desktop.
//
// Start:   quickshell -p ~/.config/quickshell/wallpaper
// Toggle:  ~/.config/hypr/scripts/QsWallpaper.sh toggle      (SUPER W)
//
// IPC (used by the toggle script, and available to anything else):
//   quickshell ipc -p ~/.config/quickshell/wallpaper \
//       call wallpaper-carousel toggle|open|close|isOpen|refresh
//
// Keys: type to filter, Left/Right or Tab step the deck, Enter applies and
//       Escape clears then closes. Ctrl+P blows the centred wallpaper up to
//       the whole monitor, where Left/Right keep stepping and Ctrl+P or Escape
//       drops back to the deck; Ctrl+D sends it to the trash. Home/End stay
//       with the caret.
//
// Adapted from the ML4W WallpaperApp carousel (GPL-3.0): the deck geometry is
// theirs, the framing, theme loader, keys and wallpaper calls are this
// project's.

import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Widgets

PanelWindow {
    id: carousel

    property Theme theme: Theme {}
    property Wallpapers wallpapers: Wallpapers {}

    // Starts closed; QsWallpaper.sh opens it through the IPC handler.
    property bool shown: false

    // The strip is created once per screen unless it is pinned to one, so it is
    // pinned to the focused monitor. Assigned before opening, because changing
    // the screen of a visible window recreates it.
    property var targetScreen: null
    screen: targetScreen

    // While applying, the deck fades out and the strip closes.
    property bool applying: false
    readonly property int applyDelay: 550

    // Fullscreen preview of the centred wallpaper. The strip grows to the
    // whole monitor for it and keeps the keyboard, so the arrows keep stepping
    // and P or Escape drop back to the deck.
    property bool previewing: false

    // The wallpaper the deck is centred on, and the one a preview shows.
    readonly property var currentEntry: {
        var list = wallpapers.filtered;
        if (view.currentIndex < 0 || view.currentIndex >= list.length) return null;
        return list[view.currentIndex];
    }
    readonly property string previewPath: currentEntry ? currentEntry.path : ""

    // --- GEOMETRY ---
    readonly property int screenWidth: screen ? screen.width : 1920
    readonly property int screenHeight: screen ? screen.height : 1080

    // Portrait cards, the shape the deck is built around. The card is sized
    // from the monitor, not fixed: cardHeightFraction is the height and
    // cardAspect the width as a fraction of it, so one number moves both.
    // 0.36 x 1.15 is 15% larger than the original deck. Cards shrink linearly
    // from 1.0 in the middle to edgeScale at the monitor edges; the PathPercent
    // values below keep the gap between neighbours shrinking with them.
    readonly property real cardHeightFraction: 0.36 * 1.45
    readonly property real cardAspect: 0.9
    readonly property real cardHeight: Math.round(screenHeight * cardHeightFraction)
    readonly property real cardWidth: Math.round(cardHeight * cardAspect)
    readonly property real cardGap: 8
    readonly property real edgeScale: 0.4

    // The search bar floats under the deck, wider than a card so a long file
    // name stays readable.
    readonly property int searchBarHeight: 34
    readonly property int searchBarWidth: Math.min(width - 60, 640)

    // Only the deck and the chrome under it: no panel, so nothing covers the
    // wallpaper behind the cards. The 120 is the 8px top margin, the 12px gap,
    // the search bar, and the key hints, caption and error lines below it.
    readonly property int stripHeight: Math.round(cardHeight + 120)
    readonly property int maxVisibleCards: Math.max(3, Math.round(width / (cardWidth + cardGap) * 1.527))

    // Full monitor width, one strip tall, centred vertically, and the whole
    // monitor while a preview is up. The strip collapses to a single pixel
    // while closed: a mapped surface is what keeps the shell alive between
    // toggles, and a floating strip that stayed mapped would sit over the
    // desktop.
    visible: true
    color: carousel.previewing ? carousel.theme.bg : "transparent"
    exclusiveZone: 0
    implicitWidth: carousel.shown ? 0 : 1
    implicitHeight: carousel.shown
        ? (carousel.previewing ? carousel.screenHeight : carousel.stripHeight)
        : 1
    anchors.left: true
    anchors.right: carousel.shown
    anchors.top: true
    margins.top: carousel.previewing
        ? 0
        : Math.max(0, Math.round((carousel.screenHeight - carousel.stripHeight) / 2))

    WlrLayershell.layer: carousel.shown ? WlrLayer.Overlay : WlrLayer.Background
    WlrLayershell.namespace: "quickshell:wallpaper-carousel"
    WlrLayershell.keyboardFocus: carousel.shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    onShownChanged: {
        if (!shown) {
            applying = false;
            previewing = false;
            wallpapers.query = "";
            return;
        }
        wallpapers.refresh();
        focusCurrent();
        searchInput.forceActiveFocus();
    }

    function screenForFocusedMonitor() {
        var focused = Hyprland.focusedMonitor;
        if (!focused) return null;
        for (var index = 0; index < Quickshell.screens.length; index++) {
            if (Quickshell.screens[index].name === focused.name) return Quickshell.screens[index];
        }
        return null;
    }

    // `query` comes from the IPC handler (QsWallpaper.sh open --query TEXT) and
    // filters the deck before it is shown. It is the same `wallpapers.query` the
    // search bar writes, so the bar opens already filled.
    function open(query) {
        var match = screenForFocusedMonitor();
        if (match) carousel.targetScreen = match;
        wallpapers.query = typeof query === "string" ? query : "";
        applying = false;
        shown = true;
    }

    function close() {
        previewing = false;
        shown = false;
    }

    function toggle() {
        if (shown) close();
        else open();
    }

    // Centre the deck on the wallpaper that is on screen, without animating.
    function focusCurrent() {
        var list = wallpapers.filtered;
        if (list.length === 0) return;

        var index = 0;
        for (var position = 0; position < list.length; position++) {
            if (wallpapers.isCurrent(list[position].path)) {
                index = position;
                break;
            }
        }
        view.currentIndex = index;
        view.positionViewAtIndex(index, PathView.Center);
    }

    function applyCurrent() {
        if (applying) return;
        var list = wallpapers.filtered;
        if (view.currentIndex < 0 || view.currentIndex >= list.length) return;

        previewing = false;
        applying = true;
        wallpapers.apply(list[view.currentIndex].path);
        closeTimer.restart();
    }

    // The search field holds the focus and takes the printable keys, which
    // filter the deck; Home/End move the caret. Left/Right and Tab step the
    // deck, Ctrl+P previews, Ctrl+D deletes, Escape unwinds, and Enter arrives
    // through the field's accepted signal.
    function handleEscape() {
        // Escape unwinds one layer at a time: the preview, then the filter,
        // then the deck.
        if (previewing) {
            previewing = false;
            return;
        }
        if (wallpapers.query !== "") {
            wallpapers.query = "";
            return;
        }
        close();
    }

    function stepDeck(delta) {
        if (applying) return;
        if (delta > 0) view.incrementCurrentIndex();
        else view.decrementCurrentIndex();
    }

    // Ctrl+P on the deck: the centred wallpaper fills the monitor. The deck
    // stays mounted underneath at opacity 0, which is what keeps the keyboard
    // focus (and the arrows) on this surface.
    function togglePreview() {
        if (applying) return;
        if (previewing) {
            previewing = false;
            return;
        }
        if (currentEntry === null) return;
        previewing = true;
    }

    // Ctrl+D on the deck: the centred wallpaper goes to the trash. The preview
    // closes with it, because the image behind it is gone.
    function deleteCurrent() {
        if (applying) return;
        var entry = currentEntry;
        if (entry === null) return;
        previewing = false;
        wallpapers.remove(entry.path);
    }

    Component.onCompleted: {
        var match = screenForFocusedMonitor();
        if (match) carousel.targetScreen = match;
    }

    Timer {
        id: closeTimer

        interval: carousel.applyDelay
        onTriggered: carousel.close()
    }

    Connections {
        target: carousel.wallpapers

        function onFilteredChanged() {
            carousel.focusCurrent();
        }
    }

    // The field is the only thing that types, but the query is also set from
    // outside: the IPC filter, Escape clearing it, and the close. The field
    // follows it, so those land in the bar.
    Connections {
        target: carousel.wallpapers

        function onQueryChanged() {
            if (searchInput.text !== carousel.wallpapers.query)
                searchInput.text = carousel.wallpapers.query;
        }
    }

    Item {
        id: content

        anchors.fill: parent
        opacity: carousel.shown && !carousel.applying && !carousel.previewing ? 1.0 : 0.0
        scale: carousel.shown && !carousel.applying && !carousel.previewing ? 1.0 : 0.97
        // Hidden behind the preview: clicks belong to it, not to the deck.
        enabled: !carousel.previewing

        Behavior on opacity {
            NumberAnimation {
                duration: 170
                easing.type: Easing.OutCubic
            }
        }

        Behavior on scale {
            NumberAnimation {
                duration: 170
                easing.type: Easing.OutCubic
            }
        }

        // Empty space in the strip closes the deck. Behind the cards, so a card
        // click still applies its wallpaper.
        MouseArea {
            anchors.fill: parent
            onClicked: carousel.close()
        }

        // --- EMPTY STATE ---
        Text {
            anchors.centerIn: parent
            width: Math.min(parent.width - 60, 560)
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            color: carousel.theme.text
            font.family: carousel.theme.fontFamily
            font.pixelSize: 15
            visible: carousel.wallpapers.count === 0
                || carousel.wallpapers.filtered.length === 0
            text: carousel.wallpapers.count === 0
                ? "No wallpapers found in " + (carousel.wallpapers.folder === ""
                    ? "your wallpaper folder" : carousel.wallpapers.folder)
                : "Nothing matches \"" + carousel.wallpapers.query + "\""
        }

        // --- DECK ---
        PathView {
            id: view

            anchors.top: parent.top
            anchors.topMargin: 8
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width
            height: carousel.cardHeight
            model: carousel.wallpapers.filtered
            pathItemCount: Math.min(carousel.wallpapers.filtered.length, carousel.maxVisibleCards)
            cacheItemCount: 4
            interactive: false
            preferredHighlightBegin: 0.5
            preferredHighlightEnd: 0.5
            highlightRangeMode: PathView.StrictlyEnforceRange
            highlightMoveDuration: 260
            enabled: !carousel.applying

            // With fewer wallpapers than slots, PathView spreads them over the
            // whole path. Shorten the path instead so the deck stays together.
            readonly property real pathWidth: width * Math.min(1,
                carousel.wallpapers.filtered.length / carousel.maxVisibleCards)
            readonly property real pathLeft: (width - pathWidth) / 2

            path: Path {
                startX: view.pathLeft
                startY: view.height / 2
                PathAttribute { name: "itemScale"; value: carousel.edgeScale }
                PathAttribute { name: "itemZ"; value: 0 }
                PathAttribute { name: "itemOpacity"; value: 0.6 }
                PathLine { x: view.pathLeft + view.pathWidth * 0.125; y: view.height / 2 }
                PathPercent { value: 0.1738 }
                PathAttribute { name: "itemScale"; value: 0.55 }
                PathAttribute { name: "itemZ"; value: 1 }
                PathAttribute { name: "itemOpacity"; value: 0.7 }
                PathLine { x: view.pathLeft + view.pathWidth * 0.25; y: view.height / 2 }
                PathPercent { value: 0.3054 }
                PathAttribute { name: "itemScale"; value: 0.7 }
                PathAttribute { name: "itemZ"; value: 2 }
                PathAttribute { name: "itemOpacity"; value: 0.8 }
                PathLine { x: view.pathLeft + view.pathWidth * 0.375; y: view.height / 2 }
                PathPercent { value: 0.4113 }
                PathAttribute { name: "itemScale"; value: 0.85 }
                PathAttribute { name: "itemZ"; value: 3 }
                PathAttribute { name: "itemOpacity"; value: 0.9 }
                PathLine { x: view.pathLeft + view.pathWidth * 0.5; y: view.height / 2 }
                PathPercent { value: 0.5 }
                PathAttribute { name: "itemScale"; value: 1.0 }
                PathAttribute { name: "itemZ"; value: 4 }
                PathAttribute { name: "itemOpacity"; value: 1.0 }
                PathLine { x: view.pathLeft + view.pathWidth * 0.625; y: view.height / 2 }
                PathPercent { value: 0.5887 }
                PathAttribute { name: "itemScale"; value: 0.85 }
                PathAttribute { name: "itemZ"; value: 3 }
                PathAttribute { name: "itemOpacity"; value: 0.9 }
                PathLine { x: view.pathLeft + view.pathWidth * 0.75; y: view.height / 2 }
                PathPercent { value: 0.6946 }
                PathAttribute { name: "itemScale"; value: 0.7 }
                PathAttribute { name: "itemZ"; value: 2 }
                PathAttribute { name: "itemOpacity"; value: 0.8 }
                PathLine { x: view.pathLeft + view.pathWidth * 0.875; y: view.height / 2 }
                PathPercent { value: 0.8262 }
                PathAttribute { name: "itemScale"; value: 0.55 }
                PathAttribute { name: "itemZ"; value: 1 }
                PathAttribute { name: "itemOpacity"; value: 0.7 }
                PathLine { x: view.pathLeft + view.pathWidth; y: view.height / 2 }
                PathPercent { value: 1.0 }
                PathAttribute { name: "itemScale"; value: carousel.edgeScale }
                PathAttribute { name: "itemZ"; value: 0 }
                PathAttribute { name: "itemOpacity"; value: 0.6 }
            }

            delegate: Item {
                id: card

                required property int index
                required property var modelData

                readonly property bool isCurrent: PathView.isCurrentItem

                width: carousel.cardWidth
                height: carousel.cardHeight
                scale: PathView.itemScale === undefined ? carousel.edgeScale : PathView.itemScale
                z: PathView.itemZ === undefined ? 0 : PathView.itemZ
                opacity: PathView.itemOpacity === undefined ? 0.6 : PathView.itemOpacity

                ClippingRectangle {
                    id: frame

                    anchors.fill: parent
                    radius: 6
                    color: carousel.theme.surface

                    Image {
                        anchors.fill: parent
                        source: "file://" + card.modelData.path
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        sourceSize.width: carousel.cardWidth
                        sourceSize.height: carousel.cardHeight
                        opacity: status === Image.Ready ? 1.0 : 0.0

                        Behavior on opacity {
                            NumberAnimation {
                                duration: 300
                                easing.type: Easing.OutCubic
                            }
                        }
                    }
                }

                // Border sits on top of the image, so the focused card is
                // outlined whether or not its thumbnail has loaded. The card
                // that is on screen right now gets the accent.
                Rectangle {
                    anchors.fill: frame
                    radius: frame.radius
                    color: "transparent"
                    border.width: card.isCurrent ? 3 : 1
                    border.color: card.isCurrent
                        ? carousel.theme.accent
                        : carousel.theme.border

                    Behavior on border.color {
                        ColorAnimation {
                            duration: 200
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        view.currentIndex = card.index;
                        carousel.applyCurrent();
                    }
                }
            }
        }

        // --- SEARCH BAR ---
        // Floats under the deck, wider than a card so a long file name stays
        // readable, and holds the focus: the deck has no panel to take it. It
        // writes the same `wallpapers.query` the IPC filter uses, so the deck
        // re-filters and re-centres on every keystroke.
        Rectangle {
            id: searchBar

            anchors.top: view.bottom
            anchors.topMargin: 12
            anchors.horizontalCenter: parent.horizontalCenter
            width: carousel.searchBarWidth
            height: carousel.searchBarHeight
            radius: height / 2
            color: carousel.theme.surface
            border.width: 1
            border.color: searchInput.activeFocus
                ? carousel.theme.accent
                : carousel.theme.border

            // Clicks on the bar's padding focus the field rather than falling
            // through to the strip's close-on-click area.
            MouseArea {
                anchors.fill: parent
                onClicked: searchInput.forceActiveFocus()
            }

            TextInput {
                id: searchInput

                anchors.fill: parent
                anchors.leftMargin: 16
                anchors.rightMargin: 16
                verticalAlignment: TextInput.AlignVCenter
                clip: true
                readOnly: carousel.applying || carousel.previewing
                selectByMouse: true
                focus: carousel.shown
                color: carousel.theme.text
                selectionColor: carousel.theme.accent
                selectedTextColor: carousel.theme.accentInk
                font.family: carousel.theme.fontFamily
                font.pixelSize: 14

                cursorDelegate: Rectangle {
                    width: 1
                    color: carousel.theme.accent
                }

                Text {
                    anchors.fill: parent
                    verticalAlignment: Text.AlignVCenter
                    visible: searchInput.text === ""
                    text: "Filter wallpapers…"
                    color: carousel.theme.muted
                    font: searchInput.font
                }

                // Typing is the filter; the deck follows through `filtered`.
                onTextChanged: carousel.wallpapers.query = text

                // Enter applies the centred card, as the deck always did.
                onAccepted: carousel.applyCurrent()

                // Left/Right step the deck, as Tab and the wheel do; Home/End
                // stay with the caret.
                Keys.onTabPressed: carousel.stepDeck(1)
                Keys.onBacktabPressed: carousel.stepDeck(-1)
                Keys.onLeftPressed: carousel.stepDeck(-1)
                Keys.onRightPressed: carousel.stepDeck(1)
                Keys.onEscapePressed: carousel.handleEscape()

                // Ctrl+P previews the centred wallpaper and Ctrl+D sends it to
                // the trash. Both are modifier combos, so every letter still
                // types into the filter; auto-repeat is ignored so holding the
                // key does not flicker.
                Keys.onPressed: (event) => {
                    if (event.isAutoRepeat) return;
                    if (!(event.modifiers & Qt.ControlModifier)) return;
                    if (event.key === Qt.Key_P) {
                        carousel.togglePreview();
                    } else if (event.key === Qt.Key_D) {
                        carousel.deleteCurrent();
                    } else {
                        return;
                    }
                    event.accepted = true;
                }
            }
        }

        // --- KEY HINTS ---
        Text {
            id: keyHints

            anchors.top: searchBar.bottom
            anchors.topMargin: 6
            anchors.horizontalCenter: parent.horizontalCenter
            color: carousel.theme.muted
            font.family: carousel.theme.fontFamily
            font.pixelSize: 11
            text: "Ctrl+P preview   ·   Ctrl+D delete   ·   Enter set wallpaper"
        }

        // --- NAME OF THE FOCUSED WALLPAPER ---
        Text {
            id: caption

            anchors.top: keyHints.bottom
            anchors.topMargin: 4
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.min(parent.width - 60, 640)
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideMiddle
            color: carousel.theme.text
            font.family: carousel.theme.fontFamily
            font.pixelSize: 13
            text: {
                var list = carousel.wallpapers.filtered;
                if (view.currentIndex < 0 || view.currentIndex >= list.length) return "";
                var entry = list[view.currentIndex];
                return entry.folder + "/" + entry.name;
            }
        }

        Text {
            anchors.top: caption.bottom
            anchors.topMargin: 4
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.min(parent.width - 60, 560)
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            color: carousel.theme.bad
            font.family: carousel.theme.fontFamily
            font.pixelSize: 12
            visible: carousel.wallpapers.lastError !== ""
            text: carousel.wallpapers.lastError
        }
    }

    // --- FULLSCREEN PREVIEW ---
    // The strip has already grown to the monitor, so this is the wallpaper over
    // the themed background. The deck is still mounted underneath at opacity 0,
    // so this surface keeps the keyboard and the arrows keep stepping here.
    Item {
        id: preview

        anchors.fill: parent
        visible: carousel.previewing

        Image {
            anchors.fill: parent
            source: carousel.previewPath === "" ? "" : "file://" + carousel.previewPath
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            sourceSize.width: carousel.screenWidth
            sourceSize.height: carousel.screenHeight
        }

        // A click drops back to the deck rather than applying the wallpaper.
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: carousel.previewing = false
        }

        Rectangle {
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 28
            anchors.horizontalCenter: parent.horizontalCenter
            width: previewHint.implicitWidth + 28
            height: previewHint.implicitHeight + 14
            radius: height / 2
            color: Qt.rgba(carousel.theme.bg.r, carousel.theme.bg.g,
                carousel.theme.bg.b, 0.85)

            Text {
                id: previewHint
                anchors.centerIn: parent
                color: carousel.theme.muted
                font.family: carousel.theme.fontFamily
                font.pixelSize: 12
                text: {
                    var entry = carousel.currentEntry;
                    var name = entry ? entry.folder + "/" + entry.name : "";
                    return name + "   ·   Ctrl+P or Esc to close";
                }
            }
        }
    }

    // --- MOUSE WHEEL ---
    // One card per notch (120 units). Touchpads send many small deltas, so they
    // are added up instead of stepping on every event.
    WheelHandler {
        property real accumulated: 0

        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad

        onWheel: (event) => {
            if (carousel.applying || !carousel.shown) return;
            var delta = event.angleDelta.y !== 0 ? event.angleDelta.y : event.angleDelta.x;
            accumulated += delta;
            while (accumulated >= 120) {
                view.decrementCurrentIndex();
                accumulated -= 120;
            }
            while (accumulated <= -120) {
                view.incrementCurrentIndex();
                accumulated += 120;
            }
        }
    }
}
