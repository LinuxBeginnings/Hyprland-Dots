// The keybind panel: a centred frame over a dimmed backdrop, with a search box,
// a header per category and the chord list.
//
// The list is one scrollable page of paired rows - a category header, then that
// category's binds two to a row. One page rather than two scroll areas, so both
// columns always show the same slice of the list.
//
// The surface fills the monitor while it is open and collapses to a single pixel
// while it is closed. Filling the monitor is what makes "click outside to
// dismiss" work without a second surface: the backdrop is part of this window.
// Collapsing matters twice over - quickshell exits once no window is left, so a
// mapped surface is what keeps the shell alive between toggles, and a
// full-screen surface that stayed mapped would swallow every click on the
// desktop, not just the ones aimed at the panel.

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import "root:/services"

PanelWindow {
    id: panel

    property Theme theme: Theme {}
    property Categories categories: Categories {}
    // Starts closed; QsKeybinds.sh opens it through the IPC handler.
    property bool shown: false
    property string query: ""

    // Selection is a cell of a paired row, so up/down can step over a header and
    // left/right can cross between the two columns.
    property int selectedRow: 0
    property int selectedSide: 0

    readonly property int columns: 2
    // Slightly translucent so the layer rule's blur shows through the card.
    readonly property color cardColor: Qt.rgba(theme.bg.r, theme.bg.g, theme.bg.b, 0.94)

    // Matches, tagged with the category they sort under. Built as copies: the
    // service's entries are shared with anything else that reads them.
    readonly property var matches: {
        var tokens = panel.query.toLowerCase().split(/\s+/);
        var wanted = [];
        for (var token = 0; token < tokens.length; token++) {
            if (tokens[token] !== "") wanted.push(tokens[token]);
        }

        var source = HyprlandKeybinds.keybinds;
        var out = [];
        for (var index = 0; index < source.length; index++) {
            var entry = source[index];
            if (wanted.length > 0) {
                var haystack = (entry.chord + " " + entry.description).toLowerCase();
                var hit = true;
                for (var want = 0; want < wanted.length; want++) {
                    if (haystack.indexOf(wanted[want]) === -1) {
                        hit = false;
                        break;
                    }
                }
                if (!hit) continue;
            }
            out.push({
                chord: entry.chord,
                description: entry.description,
                keys: entry.keys,
                category: panel.categories.of(entry)
            });
        }
        return out;
    }

    // Categories in display order, the empty ones dropped.
    readonly property var groups: {
        var buckets = {};
        var seen = [];
        for (var index = 0; index < panel.matches.length; index++) {
            var name = panel.matches[index].category;
            if (buckets[name] === undefined) {
                buckets[name] = [];
                seen.push(name);
            }
            buckets[name].push(panel.matches[index]);
        }

        // The configured order first, then anything a rule produced that is not
        // listed there - a new category name must not silently drop its binds.
        var order = panel.categories.order;
        var names = [];
        for (var known = 0; known < order.length; known++) {
            if (buckets[order[known]] !== undefined) names.push(order[known]);
        }
        for (var extra = 0; extra < seen.length; extra++) {
            if (order.indexOf(seen[extra]) === -1) names.push(seen[extra]);
        }

        var out = [];
        for (var group = 0; group < names.length; group++) {
            out.push({ name: names[group], entries: buckets[names[group]] });
        }
        return out;
    }

    // A cell with nothing to show. Every row carries a left and a right cell,
    // because the delegate builds both for every row it draws; a header row has
    // no bind to give them, and passing `undefined` makes that row's bindings
    // fail on `entry.keys`.
    readonly property var emptyEntry: ({ chord: "", description: "", keys: [] })

    // The list model: one header row per category, then rows of two binds.
    readonly property var rows: {
        var model = [];
        var groups = panel.groups;
        for (var group = 0; group < groups.length; group++) {
            var entries = groups[group].entries;
            model.push({
                kind: "header",
                title: groups[group].name,
                count: entries.length,
                left: panel.emptyEntry,
                right: panel.emptyEntry,
                hasRight: false
            });
            for (var index = 0; index < entries.length; index += 2) {
                var hasRight = index + 1 < entries.length;
                model.push({
                    kind: "pair",
                    left: entries[index],
                    right: hasRight ? entries[index + 1] : panel.emptyEntry,
                    hasRight: hasRight
                });
            }
        }
        return model;
    }

    visible: true
    color: "transparent"
    exclusiveZone: 0
    // Anchored on all four edges while open, so the surface is the whole
    // monitor; only top/left while closed, so it shrinks to one pixel and stops
    // taking input.
    anchors.top: true
    anchors.left: true
    anchors.right: panel.shown
    anchors.bottom: panel.shown
    implicitWidth: panel.shown ? 0 : 1
    implicitHeight: panel.shown ? 0 : 1

    WlrLayershell.layer: panel.shown ? WlrLayer.Overlay : WlrLayer.Background
    WlrLayershell.namespace: "quickshell:keybinds"
    // The search box needs the keyboard while the panel is up, and must not hold
    // it while the panel is down.
    WlrLayershell.keyboardFocus: panel.shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    function isPairRow(row) {
        return row >= 0 && row < panel.rows.length && panel.rows[row].kind === "pair";
    }

    function firstPairRow() {
        for (var row = 0; row < panel.rows.length; row++) {
            if (panel.rows[row].kind === "pair") return row;
        }
        return -1;
    }

    function selectedEntry() {
        if (!panel.isPairRow(panel.selectedRow)) return null;
        var row = panel.rows[panel.selectedRow];
        return panel.selectedSide === 1 ? row.right : row.left;
    }

    function copySelected() {
        var entry = panel.selectedEntry();
        if (entry && entry.chord !== "") Quickshell.clipboardText = entry.chord;
    }

    function resetSelection() {
        panel.selectedSide = 0;
        panel.selectedRow = panel.firstPairRow();
        list.positionViewAtBeginning();
    }

    // Up/down step over a header rather than stopping on one.
    function moveRow(step) {
        var row = panel.selectedRow;
        while (true) {
            row += step;
            if (row < 0 || row >= panel.rows.length) return;
            if (panel.rows[row].kind === "pair") break;
        }
        panel.selectedRow = row;
        list.positionViewAtIndex(row, ListView.Contain);
    }

    // Left/right stay inside the row: the other column is half a step away, and
    // there is no third one to reach.
    function moveSide(step) {
        if (!panel.isPairRow(panel.selectedRow)) return;
        var side = panel.selectedSide + step;
        if (side < 0) side = 0;
        if (side > 1) side = 1;
        if (side === 1 && !panel.rows[panel.selectedRow].hasRight) return;
        panel.selectedSide = side;
    }

    onShownChanged: {
        if (!shown) return;
        // Ask for a fresh list on every open: a bind added with `hyprctl eval`
        // since the last config load is in the compositor but not in the cache.
        HyprlandKeybinds.refresh();
        panel.query = "";
        search.text = "";
        panel.resetSelection();
        search.forceActiveFocus();
    }

    // Dimmed backdrop, and the click target for "click outside to dismiss".
    Rectangle {
        anchors.fill: parent
        visible: panel.shown
        color: "#000000"
        opacity: 0.35

        MouseArea {
            anchors.fill: parent
            onClicked: panel.shown = false
        }
    }

    Rectangle {
        id: card

        anchors.centerIn: parent
        // 15% up on the single-column frame, and as much of that as the monitor
        // allows: the width is what buys the second column, the height a longer
        // run of binds before a scroll.
        width: Math.min(1426, panel.width - 60)
        height: Math.max(260, Math.min(989, panel.height - 40))
        visible: panel.shown
        radius: 16
        color: panel.cardColor
        border.width: 1
        border.color: panel.theme.border
        opacity: panel.shown ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: 120
            }
        }

        // Swallow clicks on the card so they cannot reach the backdrop.
        MouseArea {
            anchors.fill: parent
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 10

            // ------------------------------------------------------------ header
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Rectangle {
                    width: 3
                    height: 16
                    radius: 1.5
                    color: panel.theme.accent
                }

                Text {
                    text: "Keybinds"
                    color: panel.theme.text
                    font.family: panel.theme.fontFamily
                    font.pixelSize: 14
                    font.bold: true
                }

                Text {
                    Layout.fillWidth: true
                    text: HyprlandKeybinds.loaded
                        ? panel.matches.length + (panel.query === ""
                            ? " of " + HyprlandKeybinds.keybinds.length : " matching")
                        : "Loading…"
                    color: panel.theme.muted
                    font.family: panel.theme.fontFamily
                    font.pixelSize: 11
                }

                Rectangle {
                    width: 24
                    height: 24
                    radius: 12
                    color: closeArea.containsMouse ? panel.theme.hover : "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: "󰅖"
                        color: closeArea.containsMouse ? panel.theme.text : panel.theme.muted
                        font.family: panel.theme.iconFont
                        font.pixelSize: 13
                    }

                    MouseArea {
                        id: closeArea
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: panel.shown = false
                    }
                }
            }

            // ------------------------------------------------------------ search
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 34
                radius: 9
                color: panel.theme.surface
                border.width: 1
                border.color: search.activeFocus ? panel.theme.accent : panel.theme.border

                TextInput {
                    id: search

                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    verticalAlignment: TextInput.AlignVCenter
                    color: panel.theme.text
                    font.family: panel.theme.fontFamily
                    font.pixelSize: 12
                    selectionColor: panel.theme.accent
                    selectedTextColor: panel.theme.accentInk
                    focus: panel.shown
                    clip: true

                    Text {
                        anchors.fill: parent
                        verticalAlignment: Text.AlignVCenter
                        visible: search.text === ""
                        text: "Search by key or description…"
                        color: panel.theme.muted
                        font: search.font
                    }

                    onTextChanged: {
                        panel.query = text;
                        panel.resetSelection();
                    }

                    Keys.onUpPressed: panel.moveRow(-1)
                    Keys.onDownPressed: panel.moveRow(1)
                    Keys.onLeftPressed: panel.moveSide(-1)
                    Keys.onRightPressed: panel.moveSide(1)
                    Keys.onEscapePressed: panel.shown = false
                    onAccepted: panel.copySelected()
                }
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 1
                color: panel.theme.border
            }

            // -------------------------------------------------------------- list
            // One ListView, so one scroll position covers both columns and a
            // header can span the full width.
            Item {
                id: listArea

                Layout.fillWidth: true
                Layout.fillHeight: true
                // Keeps the footer clear of the list: the viewport clips a row in
                // half at its edge, and against the footer text that reads as the
                // keybinds being cut off.
                Layout.bottomMargin: 8

                readonly property real columnSpacing: 14
                readonly property real cellWidth: Math.max(240,
                    Math.floor((listArea.width - listArea.columnSpacing) / panel.columns))
                // Wide enough for a four-cap chord at the smallest cell, and no
                // wider than a four-cap chord needs at the largest.
                readonly property int chordWidth: Math.max(212,
                    Math.min(258, Math.round(listArea.cellWidth * 0.44)))

                ListView {
                    id: list

                    anchors.fill: parent
                    clip: true
                    model: panel.rows
                    spacing: 2
                    // A gap after the last row, so scrolling to the end does not
                    // leave it flush against the frame.
                    bottomMargin: 6
                    boundsBehavior: Flickable.StopAtBounds

                    delegate: Item {
                        id: rowDelegate

                        required property var modelData
                        required property int index

                        width: list.width
                        implicitHeight: modelData.kind === "header"
                            ? headerRow.height
                            : cellRow.implicitHeight

                        Row {
                            id: headerRow

                            anchors.left: parent.left
                            anchors.leftMargin: 10
                            visible: rowDelegate.modelData.kind === "header"
                            height: 36
                            spacing: 8

                            Rectangle {
                                width: 3
                                height: 15
                                radius: 1.5
                                color: panel.theme.accent
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Text {
                                text: rowDelegate.modelData.title
                                color: panel.theme.text
                                font.family: panel.theme.fontFamily
                                font.pixelSize: 12
                                font.bold: true
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Text {
                                text: rowDelegate.modelData.count
                                color: panel.theme.muted
                                font.family: panel.theme.fontFamily
                                font.pixelSize: 10
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        Row {
                            id: cellRow

                            visible: rowDelegate.modelData.kind === "pair"
                            spacing: listArea.columnSpacing

                            KeybindRow {
                                width: listArea.cellWidth
                                theme: panel.theme
                                entry: rowDelegate.modelData.left
                                selected: panel.selectedRow === rowDelegate.index
                                    && panel.selectedSide === 0
                                chordColumnWidth: listArea.chordWidth

                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: {
                                        panel.selectedRow = rowDelegate.index;
                                        panel.selectedSide = 0;
                                    }
                                    onDoubleClicked: panel.copySelected()
                                }
                            }

                            KeybindRow {
                                width: listArea.cellWidth
                                visible: rowDelegate.modelData.hasRight
                                theme: panel.theme
                                entry: rowDelegate.modelData.right
                                selected: panel.selectedRow === rowDelegate.index
                                    && panel.selectedSide === 1
                                chordColumnWidth: listArea.chordWidth

                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: {
                                        panel.selectedRow = rowDelegate.index;
                                        panel.selectedSide = 1;
                                    }
                                    onDoubleClicked: panel.copySelected()
                                }
                            }
                        }
                    }
                }

                Text {
                    anchors.centerIn: parent
                    visible: panel.matches.length === 0
                    text: HyprlandKeybinds.loaded
                        ? "No keybind matches “" + panel.query + "”"
                        : (HyprlandKeybinds.note !== "" ? HyprlandKeybinds.note : "Loading…")
                    color: panel.theme.muted
                    font.family: panel.theme.fontFamily
                    font.pixelSize: 12
                }
            }

            // ------------------------------------------------------------ footer
            Text {
                Layout.fillWidth: true
                text: "↑ ↓ move · Enter copies the chord · Esc or a click outside closes"
                color: panel.theme.muted
                font.family: panel.theme.fontFamily
                font.pixelSize: 10
                elide: Text.ElideRight
            }
        }
    }
}
