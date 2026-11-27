// Keybindings view for KoolDots Control Center

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "../components"

Item {
    id: kbView

    property var theme: null
    property var backend: null
    property var helpService: null

    property string activeFilter: "all"
    property string searchQuery: ""
    property var selectedBind: null
    property bool isEditing: false

    // Editable fields
    property string editMods: "SUPER"
    property string editKey: ""
    property string editType: "exec"
    property string editAction: ""
    property string editDesc: ""

    readonly property var categories: [
        { "id": "all", "title": "All Shortcuts", "icon": "󰌌", "count": backend ? backend.keybinds.length : 0 },
        { "id": "user", "title": "User Defined", "icon": "󰀵", "count": backend ? (backend.keybinds.filter(function(b){ return b.source === 'user'; }).length) : 0 },
        { "id": "system", "title": "System Core", "icon": "󰒓", "count": backend ? (backend.keybinds.filter(function(b){ return b.source === 'system'; }).length) : 0 },
        { "id": "apps", "title": "Applications", "icon": "󰵚", "count": backend ? (backend.keybinds.filter(function(b){ return b.action_type === 'exec'; }).length) : 0 },
        { "id": "dispatch", "title": "Compositor Actions", "icon": "󰍹", "count": backend ? (backend.keybinds.filter(function(b){ return b.action_type === 'dispatch'; }).length) : 0 }
    ]

    readonly property var filteredBinds: {
        if (!backend || !backend.keybinds) return [];
        var q = searchQuery.toLowerCase().trim();
        var list = backend.keybinds;

        // Category filter
        if (activeFilter === "user") {
            list = list.filter(function(b) { return b.source === 'user'; });
        } else if (activeFilter === "system") {
            list = list.filter(function(b) { return b.source === 'system'; });
        } else if (activeFilter === "apps") {
            list = list.filter(function(b) { return b.action_type === 'exec'; });
        } else if (activeFilter === "dispatch") {
            list = list.filter(function(b) { return b.action_type === 'dispatch'; });
        }

        // Search query filter
        if (q !== "") {
            list = list.filter(function(b) {
                return (b.chord && b.chord.toLowerCase().indexOf(q) !== -1) ||
                       (b.description && b.description.toLowerCase().indexOf(q) !== -1) ||
                       (b.action && b.action.toLowerCase().indexOf(q) !== -1);
            });
        }
        return list;
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 10

        // Contextual Help Drawer
        HelpDrawer {
            Layout.fillWidth: true
            theme: kbView.theme
            helpData: kbView.helpService ? kbView.helpService.getHelp("keybinds") : null
        }

        // Main Body: Subcategory Sidebar + List/Editor
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 12

            // Subcategory Sidebar
            SubcategoryNav {
                Layout.fillHeight: true
                theme: kbView.theme
                categories: kbView.categories
                activeSubcategory: kbView.activeFilter
                onSubcategorySelected: function(catId) {
                    kbView.activeFilter = catId;
                }
            }

            // Right Panel: Search Bar + List + Inline Editor
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 10

                // Search Bar + New Bind Button
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 34
                        radius: 6
                        color: theme ? theme.surface : "#202024"
                        border.width: 1
                        border.color: kbSearchInput.activeFocus ? (theme ? theme.accent : "#cba6f7") : (theme ? theme.border : "#35353d")

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            spacing: 8

                            Text {
                                text: ""
                                font.family: theme ? theme.iconFont : "sans-serif"
                                font.pixelSize: 12
                                color: theme ? theme.muted : "#888888"
                            }

                            TextInput {
                                id: kbSearchInput
                                Layout.fillWidth: true
                                font.family: theme ? theme.fontFamily : "sans-serif"
                                font.pixelSize: 12
                                color: theme ? theme.text : "#ffffff"
                                clip: true
                                onTextChanged: kbView.searchQuery = text

                                Text {
                                    anchors.fill: parent
                                    text: "Search shortcuts by key, chord, or action description..."
                                    font: parent.font
                                    color: theme ? theme.muted : "#666666"
                                    visible: !kbSearchInput.text && !kbSearchInput.activeFocus
                                }
                            }

                            Text {
                                visible: kbSearchInput.text.length > 0
                                text: "✕"
                                font.pixelSize: 11
                                color: theme ? theme.muted : "#888888"
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        kbSearchInput.text = "";
                                        kbView.searchQuery = "";
                                    }
                                }
                            }
                        }
                    }

                    // Add Custom Shortcut Button
                    Rectangle {
                        implicitWidth: addBtnText.implicitWidth + 24
                        implicitHeight: 34
                        radius: 6
                        color: addMouse.containsMouse ? (theme ? Qt.lighter(theme.accent, 1.1) : "#d9b8ff") : (theme ? theme.accent : "#cba6f7")

                        Text {
                            id: addBtnText
                            anchors.centerIn: parent
                            text: "+ Add Keybind"
                            font.family: theme ? theme.fontFamily : "sans-serif"
                            font.pixelSize: 11
                            font.bold: true
                            color: theme ? theme.accentInk : "#111111"
                        }

                        MouseArea {
                            id: addMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                kbView.selectedBind = null;
                                kbView.editMods = "SUPER";
                                kbView.editKey = "";
                                kbView.editType = "exec";
                                kbView.editAction = "";
                                kbView.editDesc = "";
                                kbView.isEditing = true;
                            }
                        }
                    }
                }

                // Split Area: List on left/top, Editor sheet on bottom if editing
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: 8
                    color: theme ? theme.surface : "#1c1c20"
                    border.width: 1
                    border.color: theme ? theme.border : "#303036"
                    clip: true

                    ListView {
                        id: bindsList
                        anchors.fill: parent
                        anchors.margins: 6
                        model: kbView.filteredBinds
                        spacing: 4
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds

                        delegate: Rectangle {
                            id: rowRec
                            required property var modelData
                            width: bindsList.width
                            implicitHeight: 46
                            radius: 6
                            color: kbView.selectedBind === modelData
                                ? (theme ? theme.surfaceAlt : "#2a2a32")
                                : (rowMouse.containsMouse ? (theme ? theme.hover : "#24242a") : "transparent")
                            border.width: kbView.selectedBind === modelData ? 1 : 0
                            border.color: theme ? theme.accent : "#cba6f7"

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 12
                                spacing: 12

                                // Keycaps Chord Badge
                                Rectangle {
                                    implicitWidth: chordText.implicitWidth + 14
                                    implicitHeight: 26
                                    radius: 5
                                    color: theme ? theme.surfaceAlt : "#2a2a30"
                                    border.width: 1
                                    border.color: theme ? theme.border : "#3a3a44"

                                    Text {
                                        id: chordText
                                        anchors.centerIn: parent
                                        text: rowRec.modelData.chord || ""
                                        font.family: theme ? theme.fontFamily : "monospace"
                                        font.pixelSize: 11
                                        font.bold: true
                                        color: theme ? theme.accent : "#cba6f7"
                                    }
                                }

                                // Source Badge: System vs User Defined
                                Rectangle {
                                    implicitWidth: srcText.implicitWidth + 10
                                    implicitHeight: 18
                                    radius: 9
                                    color: rowRec.modelData.source === "user"
                                        ? (theme ? Qt.rgba(theme.good.r, theme.good.g, theme.good.b, 0.2) : "#1f3824")
                                        : (theme ? Qt.rgba(theme.info.r, theme.info.g, theme.info.b, 0.2) : "#1c2c3e")
                                    border.width: 1
                                    border.color: rowRec.modelData.source === "user"
                                        ? (theme ? theme.good : "#a6e3a1")
                                        : (theme ? theme.info : "#89b4fa")

                                    Text {
                                        id: srcText
                                        anchors.centerIn: parent
                                        text: rowRec.modelData.source === "user" ? "User Defined" : "System"
                                        font.pixelSize: 9
                                        font.bold: true
                                        color: rowRec.modelData.source === "user"
                                            ? (theme ? theme.good : "#a6e3a1")
                                            : (theme ? theme.info : "#89b4fa")
                                    }
                                }

                                // Description & Action Command
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 2

                                    Text {
                                        text: rowRec.modelData.description || "Shortcut action"
                                        font.family: theme ? theme.fontFamily : "sans-serif"
                                        font.pixelSize: 12
                                        font.bold: true
                                        color: theme ? theme.text : "#ffffff"
                                        elide: Text.ElideRight
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        text: rowRec.modelData.action || ""
                                        font.family: theme ? theme.fontFamily : "monospace"
                                        font.pixelSize: 10
                                        color: theme ? theme.muted : "#888888"
                                        elide: Text.ElideRight
                                    }
                                }
                            }

                            MouseArea {
                                id: rowMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    kbView.selectedBind = rowRec.modelData;
                                    kbView.editMods = rowRec.modelData.mods || "SUPER";
                                    kbView.editKey = rowRec.modelData.key || "";
                                    kbView.editType = rowRec.modelData.action_type || "exec";
                                    kbView.editAction = rowRec.modelData.action || "";
                                    kbView.editDesc = rowRec.modelData.description || "";
                                    kbView.isEditing = true;
                                }
                            }
                        }
                    }
                }

                // Inline Editor / Parameter Sheet
                Rectangle {
                    visible: kbView.isEditing
                    Layout.fillWidth: true
                    implicitHeight: 140
                    radius: 8
                    color: theme ? theme.surfaceAlt : "#222228"
                    border.width: 1
                    border.color: theme ? theme.border : "#35353d"

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 8

                        Text {
                            text: kbView.selectedBind ? "Edit / Remap Shortcut: " + kbView.selectedBind.chord : "Create New Shortcut"
                            font.family: theme ? theme.fontFamily : "sans-serif"
                            font.pixelSize: 12
                            font.bold: true
                            color: theme ? theme.accent : "#cba6f7"
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            // Modifiers input
                            Text { text: "Mods:"; font.pixelSize: 11; color: theme ? theme.muted : "#888888" }
                            Rectangle {
                                implicitWidth: 140
                                implicitHeight: 28
                                radius: 4
                                color: theme ? theme.surface : "#1a1a1e"
                                border.width: 1
                                border.color: theme ? theme.border : "#35353d"
                                TextInput {
                                    anchors.fill: parent
                                    anchors.margins: 6
                                    text: kbView.editMods
                                    font.family: theme ? theme.fontFamily : "monospace"
                                    font.pixelSize: 11
                                    color: theme ? theme.text : "#ffffff"
                                    onTextChanged: kbView.editMods = text
                                }
                            }

                            // Key name input
                            Text { text: "Key:"; font.pixelSize: 11; color: theme ? theme.muted : "#888888" }
                            Rectangle {
                                implicitWidth: 100
                                implicitHeight: 28
                                radius: 4
                                color: theme ? theme.surface : "#1a1a1e"
                                border.width: 1
                                border.color: theme ? theme.border : "#35353d"
                                TextInput {
                                    anchors.fill: parent
                                    anchors.margins: 6
                                    text: kbView.editKey
                                    font.family: theme ? theme.fontFamily : "monospace"
                                    font.pixelSize: 11
                                    color: theme ? theme.text : "#ffffff"
                                    onTextChanged: kbView.editKey = text
                                }
                            }

                            // Description input
                            Text { text: "Desc:"; font.pixelSize: 11; color: theme ? theme.muted : "#888888" }
                            Rectangle {
                                Layout.fillWidth: true
                                implicitHeight: 28
                                radius: 4
                                color: theme ? theme.surface : "#1a1a1e"
                                border.width: 1
                                border.color: theme ? theme.border : "#35353d"
                                TextInput {
                                    anchors.fill: parent
                                    anchors.margins: 6
                                    text: kbView.editDesc
                                    font.family: theme ? theme.fontFamily : "sans-serif"
                                    font.pixelSize: 11
                                    color: theme ? theme.text : "#ffffff"
                                    onTextChanged: kbView.editDesc = text
                                }
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            Text { text: "Action:"; font.pixelSize: 11; color: theme ? theme.muted : "#888888" }
                            Rectangle {
                                Layout.fillWidth: true
                                implicitHeight: 28
                                radius: 4
                                color: theme ? theme.surface : "#1a1a1e"
                                border.width: 1
                                border.color: theme ? theme.border : "#35353d"
                                TextInput {
                                    anchors.fill: parent
                                    anchors.margins: 6
                                    text: kbView.editAction
                                    font.family: theme ? theme.fontFamily : "monospace"
                                    font.pixelSize: 11
                                    color: theme ? theme.text : "#ffffff"
                                    onTextChanged: kbView.editAction = text
                                }
                            }

                            // Dismiss Editor Button
                            Rectangle {
                                implicitWidth: 70
                                implicitHeight: 28
                                radius: 4
                                color: cancelEditMouse.containsMouse ? (theme ? theme.hover : "#303038") : "transparent"
                                border.width: 1
                                border.color: theme ? theme.border : "#35353d"

                                Text {
                                    anchors.centerIn: parent
                                    text: "Cancel"
                                    font.pixelSize: 11
                                    color: theme ? theme.muted : "#888888"
                                }

                                MouseArea {
                                    id: cancelEditMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: kbView.isEditing = false
                                }
                            }
                        }
                    }
                }
            }
        }

        // Bottom Action Bar
        ActionButtons {
            Layout.fillWidth: true
            theme: kbView.theme
            backend: kbView.backend
            targetFile: backend ? backend.configHome + "/hypr/UserConfigs/user_keybinds.lua" : ""
            canApply: kbView.isEditing && kbView.editKey.length > 0
            onApplyClicked: {
                if (backend && kbView.editKey.length > 0) {
                    var origMods = kbView.selectedBind ? kbView.selectedBind.mods : "";
                    var origKey = kbView.selectedBind ? kbView.selectedBind.key : "";
                    backend.applyKeybind(
                        kbView.editMods, kbView.editKey,
                        kbView.editType, kbView.editAction,
                        kbView.editDesc, origMods, origKey
                    );
                    kbView.isEditing = false;
                }
            }
            onValidateClicked: {
                if (backend) {
                    backend.busy = true;
                    validateKbProcess.running = true;
                }
            }
        }
    }

    // Process for inline validation test
    Process {
        id: validateKbProcess
        command: [backend ? backend.script : "", "validate-keybinds"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (backend) backend.busy = false;
                try {
                    var res = JSON.parse(text);
                    if (res.valid) {
                        if (backend) {
                            backend.statusMessage = "All keybinding definitions and syntax are valid!";
                            backend.statusType = "success";
                        }
                    } else {
                        if (backend) {
                            backend.statusMessage = "Validation error: " + res.error;
                            backend.statusType = "error";
                            backend.hasError = true;
                            backend.lastErrorMessage = res.error;
                            backend.lastErrorTarget = "user_keybinds.lua";
                        }
                    }
                } catch (e) {}
            }
        }
    }
}
