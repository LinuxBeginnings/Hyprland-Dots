// Window & Layer Rules view for KoolDots Control Center

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "../components"

Item {
    id: rulesView

    property var theme: null
    property var backend: null
    property var helpService: null

    property string activeFilter: "all"
    property string searchQuery: ""
    property var selectedRule: null
    property bool isEditing: false

    // Editable form state
    property string editName: "custom-rule"
    property string editClass: ""
    property string editTitle: ""
    property string editTag: ""
    property bool editFloat: true
    property bool editCenter: true
    property string editSize: ""
    property string editOpacity: ""
    property string editWorkspace: ""

    readonly property var categories: [
        { "id": "all", "title": "All Rules", "icon": "󰖲", "count": backend ? backend.windowRules.length : 0 },
        { "id": "user", "title": "User Rules", "icon": "󰀵", "count": backend ? (backend.windowRules.filter(function(r){ return r.source === 'user'; }).length) : 0 },
        { "id": "system", "title": "System Rules", "icon": "󰒓", "count": backend ? (backend.windowRules.filter(function(r){ return r.source === 'system'; }).length) : 0 },
        { "id": "floating", "title": "Floating Rules", "icon": "󰖰", "count": backend ? (backend.windowRules.filter(function(r){ return r.actions && r.actions.float; }).length) : 0 },
        { "id": "workspace", "title": "Workspace Pins", "icon": "󰍹", "count": backend ? (backend.windowRules.filter(function(r){ return r.actions && r.actions.workspace; }).length) : 0 }
    ]

    readonly property var filteredRules: {
        if (!backend || !backend.windowRules) return [];
        var q = searchQuery.toLowerCase().trim();
        var list = backend.windowRules;

        if (activeFilter === "user") {
            list = list.filter(function(r) { return r.source === 'user'; });
        } else if (activeFilter === "system") {
            list = list.filter(function(r) { return r.source === 'system'; });
        } else if (activeFilter === "floating") {
            list = list.filter(function(r) { return r.actions && r.actions.float; });
        } else if (activeFilter === "workspace") {
            list = list.filter(function(r) { return r.actions && r.actions.workspace; });
        }

        if (q !== "") {
            list = list.filter(function(r) {
                return (r.name && r.name.toLowerCase().indexOf(q) !== -1) ||
                       (r.match && r.match.class && r.match.class.toLowerCase().indexOf(q) !== -1) ||
                       (r.match && r.match.title && r.match.title.toLowerCase().indexOf(q) !== -1);
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
            theme: rulesView.theme
            helpData: rulesView.helpService ? rulesView.helpService.getHelp("window_rules") : null
        }

        // Main Body: Subcategory Sidebar + List/Editor
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 12

            // Subcategory Sidebar
            SubcategoryNav {
                Layout.fillHeight: true
                theme: rulesView.theme
                categories: rulesView.categories
                activeSubcategory: rulesView.activeFilter
                onSubcategorySelected: function(catId) {
                    rulesView.activeFilter = catId;
                }
            }

            // Right Panel: Search Bar + Rules List + Editor
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 10

                // Search Bar + Add Rule Button
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 34
                        radius: 6
                        color: theme ? theme.surface : "#202024"
                        border.width: 1
                        border.color: rulesSearchInput.activeFocus ? (theme ? theme.accent : "#cba6f7") : (theme ? theme.border : "#35353d")

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
                                id: rulesSearchInput
                                Layout.fillWidth: true
                                font.family: theme ? theme.fontFamily : "sans-serif"
                                font.pixelSize: 12
                                color: theme ? theme.text : "#ffffff"
                                clip: true
                                onTextChanged: rulesView.searchQuery = text

                                Text {
                                    anchors.fill: parent
                                    text: "Search window rules by identifier, class, or title regex..."
                                    font: parent.font
                                    color: theme ? theme.muted : "#666666"
                                    visible: !rulesSearchInput.text && !rulesSearchInput.activeFocus
                                }
                            }

                            Text {
                                visible: rulesSearchInput.text.length > 0
                                text: "✕"
                                font.pixelSize: 11
                                color: theme ? theme.muted : "#888888"
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        rulesSearchInput.text = "";
                                        rulesView.searchQuery = "";
                                    }
                                }
                            }
                        }
                    }

                    // Add Rule Button
                    Rectangle {
                        implicitWidth: addRuleText.implicitWidth + 24
                        implicitHeight: 34
                        radius: 6
                        color: addRuleMouse.containsMouse ? (theme ? Qt.lighter(theme.accent, 1.1) : "#d9b8ff") : (theme ? theme.accent : "#cba6f7")

                        Text {
                            id: addRuleText
                            anchors.centerIn: parent
                            text: "+ New Rule"
                            font.family: theme ? theme.fontFamily : "sans-serif"
                            font.pixelSize: 11
                            font.bold: true
                            color: theme ? theme.accentInk : "#111111"
                        }

                        MouseArea {
                            id: addRuleMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                rulesView.selectedRule = null;
                                rulesView.editName = "user-rule-" + (backend ? backend.windowRules.length + 1 : 1);
                                rulesView.editClass = "";
                                rulesView.editTitle = "";
                                rulesView.editTag = "";
                                rulesView.editFloat = true;
                                rulesView.editCenter = true;
                                rulesView.editSize = "(monitor_w*0.5) (monitor_h*0.5)";
                                rulesView.editOpacity = "";
                                rulesView.editWorkspace = "";
                                rulesView.isEditing = true;
                            }
                        }
                    }
                }

                // Rules List
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: 8
                    color: theme ? theme.surface : "#1c1c20"
                    border.width: 1
                    border.color: theme ? theme.border : "#303036"
                    clip: true

                    ListView {
                        id: rList
                        anchors.fill: parent
                        anchors.margins: 6
                        model: rulesView.filteredRules
                        spacing: 4
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds

                        delegate: Rectangle {
                            id: rDelegate
                            required property var modelData
                            width: rList.width
                            implicitHeight: 52
                            radius: 6
                            color: rulesView.selectedRule === modelData
                                ? (theme ? theme.surfaceAlt : "#2a2a32")
                                : (rMouse.containsMouse ? (theme ? theme.hover : "#24242a") : "transparent")
                            border.width: rulesView.selectedRule === modelData ? 1 : 0
                            border.color: theme ? theme.accent : "#cba6f7"

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 12
                                spacing: 12

                                // Rule Icon
                                Text {
                                    text: rDelegate.modelData.actions && rDelegate.modelData.actions.float ? "󰖰" : "󰖲"
                                    font.family: theme ? theme.iconFont : "sans-serif"
                                    font.pixelSize: 14
                                    color: theme ? theme.accent : "#cba6f7"
                                }

                                // Identifier & Match Regex
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 2

                                    RowLayout {
                                        spacing: 8
                                        Text {
                                            text: rDelegate.modelData.name || "unnamed_rule"
                                            font.family: theme ? theme.fontFamily : "sans-serif"
                                            font.pixelSize: 12
                                            font.bold: true
                                            color: theme ? theme.text : "#ffffff"
                                        }

                                        Rectangle {
                                            implicitWidth: rSrcText.implicitWidth + 8
                                            implicitHeight: 16
                                            radius: 8
                                            color: rDelegate.modelData.source === "user"
                                                ? (theme ? Qt.rgba(theme.good.r, theme.good.g, theme.good.b, 0.2) : "#1f3824")
                                                : (theme ? Qt.rgba(theme.info.r, theme.info.g, theme.info.b, 0.2) : "#1c2c3e")
                                            border.width: 1
                                            border.color: rDelegate.modelData.source === "user"
                                                ? (theme ? theme.good : "#a6e3a1")
                                                : (theme ? theme.info : "#89b4fa")

                                            Text {
                                                id: rSrcText
                                                anchors.centerIn: parent
                                                text: rDelegate.modelData.source === "user" ? "User" : "System"
                                                font.pixelSize: 9
                                                font.bold: true
                                                color: rDelegate.modelData.source === "user"
                                                    ? (theme ? theme.good : "#a6e3a1")
                                                    : (theme ? theme.info : "#89b4fa")
                                            }
                                        }
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        text: "match: " + (rDelegate.modelData.match ? JSON.stringify(rDelegate.modelData.match) : "{}")
                                        font.family: theme ? theme.fontFamily : "monospace"
                                        font.pixelSize: 10
                                        color: theme ? theme.muted : "#888888"
                                        elide: Text.ElideRight
                                    }
                                }

                                // Active Action Chips
                                RowLayout {
                                    spacing: 4
                                    Repeater {
                                        model: rDelegate.modelData.actions ? Object.keys(rDelegate.modelData.actions) : []
                                        delegate: Rectangle {
                                            required property string modelData
                                            implicitWidth: actChipText.implicitWidth + 8
                                            implicitHeight: 18
                                            radius: 4
                                            color: theme ? theme.surfaceAlt : "#222228"
                                            border.width: 1
                                            border.color: theme ? theme.border : "#35353d"

                                            Text {
                                                id: actChipText
                                                anchors.centerIn: parent
                                                text: modelData + (typeof rDelegate.modelData.actions[modelData] !== 'boolean' ? (": " + rDelegate.modelData.actions[modelData]) : "")
                                                font.family: theme ? theme.fontFamily : "monospace"
                                                font.pixelSize: 9
                                                color: theme ? theme.accent : "#cba6f7"
                                            }
                                        }
                                    }
                                }
                            }

                            MouseArea {
                                id: rMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    rulesView.selectedRule = rDelegate.modelData;
                                    rulesView.editName = rDelegate.modelData.name || "";
                                    rulesView.editClass = rDelegate.modelData.match ? (rDelegate.modelData.match.class || "") : "";
                                    rulesView.editTitle = rDelegate.modelData.match ? (rDelegate.modelData.match.title || "") : "";
                                    rulesView.editTag = rDelegate.modelData.match ? (rDelegate.modelData.match.tag || "") : "";
                                    rulesView.editFloat = rDelegate.modelData.actions ? !!rDelegate.modelData.actions.float : false;
                                    rulesView.editCenter = rDelegate.modelData.actions ? !!rDelegate.modelData.actions.center : false;
                                    rulesView.editSize = rDelegate.modelData.actions ? (rDelegate.modelData.actions.size || "") : "";
                                    rulesView.editOpacity = rDelegate.modelData.actions ? (rDelegate.modelData.actions.opacity || "") : "";
                                    rulesView.editWorkspace = rDelegate.modelData.actions ? (rDelegate.modelData.actions.workspace || "") : "";
                                    rulesView.isEditing = true;
                                }
                            }
                        }
                    }
                }

                // Rule Editor Form
                Rectangle {
                    visible: rulesView.isEditing
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

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            Text {
                                text: rulesView.selectedRule ? "Edit Rule: " + rulesView.selectedRule.name : "Create New Window Rule"
                                font.family: theme ? theme.fontFamily : "sans-serif"
                                font.pixelSize: 12
                                font.bold: true
                                color: theme ? theme.accent : "#cba6f7"
                            }

                            Item { Layout.fillWidth: true }

                            // Clone Button
                            Rectangle {
                                implicitWidth: 60
                                implicitHeight: 24
                                radius: 4
                                color: cloneMouse.containsMouse ? (theme ? theme.hover : "#303038") : "transparent"
                                border.width: 1
                                border.color: theme ? theme.border : "#35353d"
                                Text { anchors.centerIn: parent; text: "Clone"; font.pixelSize: 10; color: theme ? theme.text : "#ffffff" }
                                MouseArea {
                                    id: cloneMouse
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        rulesView.editName = rulesView.editName + "-copy";
                                    }
                                }
                            }

                            // Dismiss Button
                            Rectangle {
                                implicitWidth: 60
                                implicitHeight: 24
                                radius: 4
                                color: closeEditMouse.containsMouse ? (theme ? theme.hover : "#303038") : "transparent"
                                border.width: 1
                                border.color: theme ? theme.border : "#35353d"
                                Text { anchors.centerIn: parent; text: "Cancel"; font.pixelSize: 10; color: theme ? theme.muted : "#888888" }
                                MouseArea {
                                    id: closeEditMouse
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: rulesView.isEditing = false
                                }
                            }
                        }

                        // Input fields
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            Text { text: "Name:"; font.pixelSize: 11; color: theme ? theme.muted : "#888888" }
                            Rectangle {
                                implicitWidth: 120
                                implicitHeight: 26
                                radius: 4
                                color: theme ? theme.surface : "#1a1a1e"
                                border.width: 1
                                border.color: theme ? theme.border : "#35353d"
                                TextInput { anchors.fill: parent; anchors.margins: 4; text: rulesView.editName; font.pixelSize: 11; color: theme ? theme.text : "#ffffff"; onTextChanged: rulesView.editName = text }
                            }

                            Text { text: "Class regex:"; font.pixelSize: 11; color: theme ? theme.muted : "#888888" }
                            Rectangle {
                                Layout.fillWidth: true
                                implicitHeight: 26
                                radius: 4
                                color: theme ? theme.surface : "#1a1a1e"
                                border.width: 1
                                border.color: theme ? theme.border : "#35353d"
                                TextInput { anchors.fill: parent; anchors.margins: 4; text: rulesView.editClass; font.pixelSize: 11; color: theme ? theme.text : "#ffffff"; onTextChanged: rulesView.editClass = text }
                            }

                            Text { text: "Title regex:"; font.pixelSize: 11; color: theme ? theme.muted : "#888888" }
                            Rectangle {
                                Layout.fillWidth: true
                                implicitHeight: 26
                                radius: 4
                                color: theme ? theme.surface : "#1a1a1e"
                                border.width: 1
                                border.color: theme ? theme.border : "#35353d"
                                TextInput { anchors.fill: parent; anchors.margins: 4; text: rulesView.editTitle; font.pixelSize: 11; color: theme ? theme.text : "#ffffff"; onTextChanged: rulesView.editTitle = text }
                            }
                        }

                        // Actions row
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 12

                            // Float checkbox toggle
                            RowLayout {
                                spacing: 6
                                Rectangle {
                                    width: 16; height: 16; radius: 3
                                    color: rulesView.editFloat ? (theme ? theme.accent : "#cba6f7") : "transparent"
                                    border.width: 1; border.color: theme ? theme.accent : "#cba6f7"
                                    Text { anchors.centerIn: parent; visible: rulesView.editFloat; text: "✓"; font.pixelSize: 10; color: theme ? theme.accentInk : "#111111" }
                                    MouseArea { anchors.fill: parent; onClicked: rulesView.editFloat = !rulesView.editFloat }
                                }
                                Text { text: "Float"; font.pixelSize: 11; color: theme ? theme.text : "#ffffff" }
                            }

                            // Center checkbox toggle
                            RowLayout {
                                spacing: 6
                                Rectangle {
                                    width: 16; height: 16; radius: 3
                                    color: rulesView.editCenter ? (theme ? theme.accent : "#cba6f7") : "transparent"
                                    border.width: 1; border.color: theme ? theme.accent : "#cba6f7"
                                    Text { anchors.centerIn: parent; visible: rulesView.editCenter; text: "✓"; font.pixelSize: 10; color: theme ? theme.accentInk : "#111111" }
                                    MouseArea { anchors.fill: parent; onClicked: rulesView.editCenter = !rulesView.editCenter }
                                }
                                Text { text: "Center"; font.pixelSize: 11; color: theme ? theme.text : "#ffffff" }
                            }

                            Text { text: "Size:"; font.pixelSize: 11; color: theme ? theme.muted : "#888888" }
                            Rectangle {
                                Layout.fillWidth: true
                                implicitHeight: 26
                                radius: 4
                                color: theme ? theme.surface : "#1a1a1e"
                                border.width: 1
                                border.color: theme ? theme.border : "#35353d"
                                TextInput { anchors.fill: parent; anchors.margins: 4; text: rulesView.editSize; font.pixelSize: 11; color: theme ? theme.text : "#ffffff"; onTextChanged: rulesView.editSize = text }
                            }

                            Text { text: "Workspace:"; font.pixelSize: 11; color: theme ? theme.muted : "#888888" }
                            Rectangle {
                                implicitWidth: 100
                                implicitHeight: 26
                                radius: 4
                                color: theme ? theme.surface : "#1a1a1e"
                                border.width: 1
                                border.color: theme ? theme.border : "#35353d"
                                TextInput { anchors.fill: parent; anchors.margins: 4; text: rulesView.editWorkspace; font.pixelSize: 11; color: theme ? theme.text : "#ffffff"; onTextChanged: rulesView.editWorkspace = text }
                            }
                        }
                    }
                }
            }
        }

        // Bottom Action Bar
        ActionButtons {
            Layout.fillWidth: true
            theme: rulesView.theme
            backend: rulesView.backend
            targetFile: backend ? backend.configHome + "/hypr/UserConfigs/user_window_rules.lua" : ""
            canApply: rulesView.isEditing && rulesView.editName.length > 0 && (rulesView.editClass.length > 0 || rulesView.editTitle.length > 0)
            onApplyClicked: {
                if (backend && rulesView.editName.length > 0) {
                    var matchObj = {};
                    if (rulesView.editClass) matchObj["class"] = rulesView.editClass;
                    if (rulesView.editTitle) matchObj["title"] = rulesView.editTitle;
                    if (rulesView.editTag) matchObj["tag"] = rulesView.editTag;

                    var actionsObj = {};
                    if (rulesView.editFloat) actionsObj["float"] = true;
                    if (rulesView.editCenter) actionsObj["center"] = true;
                    if (rulesView.editSize) actionsObj["size"] = rulesView.editSize;
                    if (rulesView.editOpacity) actionsObj["opacity"] = rulesView.editOpacity;
                    if (rulesView.editWorkspace) actionsObj["workspace"] = rulesView.editWorkspace;

                    backend.applyRule(rulesView.editName, matchObj, actionsObj);
                    rulesView.isEditing = false;
                }
            }
            onValidateClicked: {
                if (backend) {
                    backend.busy = true;
                    validateRulesProcess.running = true;
                }
            }
        }
    }

    // Process for inline validation
    Process {
        id: validateRulesProcess
        command: [backend ? backend.script : "", "validate", backend ? backend.configHome + "/hypr/UserConfigs/user_window_rules.lua" : ""]
        stdout: StdioCollector {
            onStreamFinished: {
                if (backend) {
                    backend.busy = false;
                    backend.statusMessage = "Window rules syntax check passed!";
                    backend.statusType = "success";
                }
            }
        }
    }
}
