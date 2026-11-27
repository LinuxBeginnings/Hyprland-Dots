// Waybar Visual Layout & Module Arranger (Phase 2)
// Visual 3-column arranger with bar preview, clone incrementing, and syntax checks.

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell.Io
import "../components"

Item {
    id: wbView

    property var theme: null
    property var backend: null
    property var helpService: null

    property var leftModules: []
    property var centerModules: []
    property var rightModules: []
    property bool isModified: false
    property bool showCloneModal: false
    property string customCloneName: ""
    property bool showAddModal: false
    property string addColumnTarget: "left"
    property string moduleSearchQuery: ""
    property bool showConfigSelector: false

    function getModuleIcon(name) {
        if (!name) return "󰐤";
        var n = name.toLowerCase();
        if (n.indexOf("clock") !== -1) return "󰥔";
        if (n.indexOf("cpu") !== -1) return "󰍛";
        if (n.indexOf("memory") !== -1) return "󰘚";
        if (n.indexOf("disk") !== -1) return "󰋊";
        if (n.indexOf("temp") !== -1) return "󰈸";
        if (n.indexOf("weather") !== -1) return "󰖐";
        if (n.indexOf("network") !== -1 || n.indexOf("wifi") !== -1) return "󰖩";
        if (n.indexOf("battery") !== -1) return "󰂄";
        if (n.indexOf("backlight") !== -1) return "󰃠";
        if (n.indexOf("pulse") !== -1 || n.indexOf("audio") !== -1 || n.indexOf("volume") !== -1) return "󰕾";
        if (n.indexOf("window") !== -1) return "󰖲";
        if (n.indexOf("workspace") !== -1) return "󰍹";
        if (n.indexOf("tray") !== -1) return "󱊖";
        if (n.indexOf("power") !== -1 || n.indexOf("session") !== -1) return "󰐥";
        if (n.indexOf("submap") !== -1) return "󰌌";
        if (n.indexOf("cava") !== -1 || n.indexOf("mviz") !== -1) return "󰎈";
        if (n.indexOf("player") !== -1 || n.indexOf("mpris") !== -1) return "󰐊";
        if (n.indexOf("menu") !== -1 || n.indexOf("launcher") !== -1) return "󰣇";
        if (n.indexOf("separator") !== -1) return "󰇝";
        if (n.indexOf("nightlight") !== -1) return "󰃞";
        if (n.indexOf("idle") !== -1) return "󰒲";
        if (n.indexOf("group") !== -1) return "󰅩";
        return "󰐤";
    }

    function syncFromBackend() {
        if (!backend || !backend.waybarLayout) return;
        var l = backend.waybarLayout.modules_left || [];
        var c = backend.waybarLayout.modules_center || [];
        var r = backend.waybarLayout.modules_right || [];
        leftModules = l.slice();
        centerModules = c.slice();
        rightModules = r.slice();
        customCloneName = backend.waybarLayout.suggested_clone || "";
        isModified = false;
    }

    Connections {
        target: backend
        function onWaybarLayoutChanged() {
            wbView.syncFromBackend();
        }
    }

    Component.onCompleted: {
        wbView.syncFromBackend();
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 10

        // Contextual Help Drawer
        HelpDrawer {
            Layout.fillWidth: true
            theme: wbView.theme
            backend: wbView.backend
            targetFile: backend && backend.waybarLayout ? (backend.configHome + "/hypr/waybar/configs/" + backend.waybarLayout.name) : ""
            helpData: wbView.helpService ? wbView.helpService.getHelp("waybar") : null
        }

        // Top Control Header: Active Config Banner, Selector, Clone Button
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 52
            radius: 8
            color: theme ? theme.surface : "#1c1c20"
            border.width: 1
            border.color: theme ? theme.border : "#303036"

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 14
                anchors.rightMargin: 14
                spacing: 12

                // Current Config Banner
                RowLayout {
                    spacing: 6
                    Text {
                        text: "Current cfg:"
                        font.family: theme ? theme.fontFamily : "sans-serif"
                        font.pixelSize: 12
                        font.bold: true
                        color: theme ? theme.muted : "#aaaaaa"
                    }

                    Rectangle {
                        implicitWidth: cfgNameText.implicitWidth + 14
                        implicitHeight: 26
                        radius: 5
                        color: backend && backend.waybarLayout && backend.waybarLayout.is_custom ? (theme ? theme.accent : "#cba6f7") : (theme ? theme.surfaceAlt : "#26262e")
                        border.width: 1
                        border.color: theme ? theme.accent : "#cba6f7"

                        Text {
                            id: cfgNameText
                            anchors.centerIn: parent
                            text: backend && backend.waybarLayout ? backend.waybarLayout.name : (backend ? backend.waybarActiveConfig : "TOP-Default")
                            font.family: theme ? theme.fontFamily : "monospace"
                            font.pixelSize: 11
                            font.bold: true
                            color: backend && backend.waybarLayout && backend.waybarLayout.is_custom ? (theme ? theme.accentInk : "#111111") : (theme ? theme.text : "#ffffff")
                        }
                    }
                }

                // Choose Layout Dropdown Button
                Rectangle {
                    implicitWidth: selBtnText.implicitWidth + 28
                    implicitHeight: 32
                    radius: 6
                    color: cfgSelectMouse.containsMouse ? (theme ? theme.hover : "#2c2c34") : (theme ? theme.surfaceAlt : "#222228")
                    border.width: 1
                    border.color: theme ? theme.border : "#35353d"

                    RowLayout {
                        id: selBtnText
                        anchors.centerIn: parent
                        spacing: 6
                        Text { text: "󰍹 Select Config"; font.pixelSize: 11; font.bold: true; color: theme ? theme.text : "#ffffff" }
                        Text { text: wbView.showConfigSelector ? "▲" : "▼"; font.pixelSize: 9; color: theme ? theme.muted : "#888888" }
                    }

                    MouseArea {
                        id: cfgSelectMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: wbView.showConfigSelector = !wbView.showConfigSelector
                    }
                }

                // Clone Config Button
                Rectangle {
                    implicitWidth: cloneBtnText.implicitWidth + 24
                    implicitHeight: 32
                    radius: 6
                    color: cloneMouse.containsMouse ? (theme ? Qt.lighter(theme.accent, 1.1) : "#d9b8ff") : (theme ? theme.accent : "#cba6f7")

                    RowLayout {
                        id: cloneBtnText
                        anchors.centerIn: parent
                        spacing: 6
                        Text { text: "󰑍"; font.pixelSize: 12; font.bold: true; color: theme ? theme.accentInk : "#111111" }
                        Text { text: "Clone Config"; font.pixelSize: 11; font.bold: true; color: theme ? theme.accentInk : "#111111" }
                    }

                    MouseArea {
                        id: cloneMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            wbView.customCloneName = backend && backend.waybarLayout ? backend.waybarLayout.suggested_clone : "[Custom-1]-TOP-Default";
                            wbView.showCloneModal = true;
                        }
                    }
                }

                Item { Layout.fillWidth: true }

                // Direct Edit active file in default editor
                Rectangle {
                    implicitWidth: editDirectText.implicitWidth + 20
                    implicitHeight: 30
                    radius: 6
                    color: editDirectMouse.containsMouse ? (theme ? theme.hover : "#2a2a32") : "transparent"
                    border.width: 1
                    border.color: theme ? theme.border : "#35353d"

                    RowLayout {
                        id: editDirectText
                        anchors.centerIn: parent
                        spacing: 6
                        Text { text: ""; font.pixelSize: 11; color: theme ? theme.info : "#89b4fa" }
                        Text { text: "Open File in Editor"; font.pixelSize: 11; color: theme ? theme.text : "#ffffff" }
                    }

                    MouseArea {
                        id: editDirectMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (backend && backend.waybarLayout && backend.waybarLayout.name) {
                                backend.editFile(backend.configHome + "/hypr/waybar/configs/" + backend.waybarLayout.name);
                            }
                        }
                    }
                }
            }
        }

        // Config Selector Drawer / Dropdown
        Rectangle {
            visible: wbView.showConfigSelector
            Layout.fillWidth: true
            implicitHeight: 120
            radius: 8
            color: theme ? theme.surfaceAlt : "#202026"
            border.width: 1
            border.color: theme ? theme.accent : "#cba6f7"
            clip: true

            ScrollView {
                anchors.fill: parent
                anchors.margins: 8

                Flow {
                    width: parent.width
                    spacing: 8

                    Repeater {
                        model: backend ? backend.waybarConfigs : []
                        delegate: Rectangle {
                            required property var modelData
                            implicitWidth: cfgPillText.implicitWidth + 18
                            implicitHeight: 28
                            radius: 6
                            color: modelData.name === (backend && backend.waybarLayout ? backend.waybarLayout.name : "")
                                ? (theme ? theme.accent : "#cba6f7")
                                : (cfgPillMouse.containsMouse ? (theme ? theme.hover : "#2c2c36") : (theme ? theme.surface : "#1a1a1e"))
                            border.width: 1
                            border.color: modelData.is_custom ? (theme ? theme.warning : "#f9e2af") : (theme ? theme.border : "#35353d")

                            RowLayout {
                                id: cfgPillText
                                anchors.centerIn: parent
                                spacing: 6
                                Text {
                                    visible: modelData.is_custom
                                    text: "★"
                                    font.pixelSize: 10
                                    color: modelData.name === (backend && backend.waybarLayout ? backend.waybarLayout.name : "") ? (theme ? theme.accentInk : "#111111") : (theme ? theme.warning : "#f9e2af")
                                }
                                Text {
                                    text: modelData.name
                                    font.family: theme ? theme.fontFamily : "monospace"
                                    font.pixelSize: 11
                                    font.bold: modelData.is_active || modelData.is_custom
                                    color: modelData.name === (backend && backend.waybarLayout ? backend.waybarLayout.name : "")
                                        ? (theme ? theme.accentInk : "#111111")
                                        : (theme ? theme.text : "#ffffff")
                                }
                            }

                            MouseArea {
                                id: cfgPillMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (backend) {
                                        backend.loadWaybarLayout(modelData.name);
                                    }
                                    wbView.showConfigSelector = false;
                                }
                            }
                        }
                    }
                }
            }
        }

        // Live Bar Visual Layout Preview Banner
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 46
            radius: 8
            color: theme ? theme.surfaceAlt : "#16161a"
            border.width: 1
            border.color: theme ? theme.border : "#282830"

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                spacing: 8

                // Left preview
                RowLayout {
                    spacing: 4
                    Repeater {
                        model: wbView.leftModules.slice(0, 6)
                        delegate: Rectangle {
                            required property string modelData
                            implicitWidth: pLText.implicitWidth + 10
                            implicitHeight: 24
                            radius: 4
                            color: theme ? theme.surface : "#222228"
                            border.width: 1
                            border.color: theme ? theme.border : "#33333d"
                            RowLayout {
                                id: pLText
                                anchors.centerIn: parent
                                spacing: 4
                                Text { text: wbView.getModuleIcon(modelData); font.pixelSize: 10; color: theme ? theme.accent : "#cba6f7" }
                                Text { text: modelData.split('/').pop().split('#')[0]; font.pixelSize: 9; color: theme ? theme.text : "#ffffff" }
                            }
                        }
                    }
                }

                Item { Layout.fillWidth: true }

                // Center preview
                RowLayout {
                    spacing: 4
                    Repeater {
                        model: wbView.centerModules.slice(0, 6)
                        delegate: Rectangle {
                            required property string modelData
                            implicitWidth: pCText.implicitWidth + 10
                            implicitHeight: 24
                            radius: 4
                            color: theme ? theme.surface : "#222228"
                            border.width: 1
                            border.color: theme ? theme.border : "#33333d"
                            RowLayout {
                                id: pCText
                                anchors.centerIn: parent
                                spacing: 4
                                Text { text: wbView.getModuleIcon(modelData); font.pixelSize: 10; color: theme ? theme.accent : "#cba6f7" }
                                Text { text: modelData.split('/').pop().split('#')[0]; font.pixelSize: 9; color: theme ? theme.text : "#ffffff" }
                            }
                        }
                    }
                }

                Item { Layout.fillWidth: true }

                // Right preview
                RowLayout {
                    spacing: 4
                    Repeater {
                        model: wbView.rightModules.slice(0, 6)
                        delegate: Rectangle {
                            required property string modelData
                            implicitWidth: pRText.implicitWidth + 10
                            implicitHeight: 24
                            radius: 4
                            color: theme ? theme.surface : "#222228"
                            border.width: 1
                            border.color: theme ? theme.border : "#33333d"
                            RowLayout {
                                id: pRText
                                anchors.centerIn: parent
                                spacing: 4
                                Text { text: wbView.getModuleIcon(modelData); font.pixelSize: 10; color: theme ? theme.accent : "#cba6f7" }
                                Text { text: modelData.split('/').pop().split('#')[0]; font.pixelSize: 9; color: theme ? theme.text : "#ffffff" }
                            }
                        }
                    }
                }
            }
        }

        // Main 3-Column Arranger Layout (Start, Center, End) matching reference image
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 12

            // ==================== COLUMN 1: START (modules-left) ====================
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: 8
                color: theme ? theme.surface : "#1c1c20"
                border.width: 1
                border.color: theme ? theme.border : "#303036"

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 8

                    // Header
                    RowLayout {
                        Layout.fillWidth: true
                        Text { text: "Start"; font.pixelSize: 13; font.bold: true; color: theme ? theme.text : "#ffffff" }
                        Rectangle {
                            implicitWidth: leftCount.implicitWidth + 10
                            implicitHeight: 18
                            radius: 9
                            color: theme ? theme.surfaceAlt : "#24242a"
                            Text { id: leftCount; anchors.centerIn: parent; text: wbView.leftModules.length; font.pixelSize: 10; color: theme ? theme.muted : "#888888" }
                        }
                        Item { Layout.fillWidth: true }
                        Text {
                            text: "Reset"
                            font.pixelSize: 11
                            color: resetLMouse.containsMouse ? (theme ? theme.accent : "#cba6f7") : (theme ? theme.muted : "#888888")
                            MouseArea {
                                id: resetLMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (backend && backend.waybarLayout) {
                                        wbView.leftModules = (backend.waybarLayout.modules_left || []).slice();
                                    }
                                }
                            }
                        }
                    }

                    // List
                    ListView {
                        id: leftList
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        spacing: 6
                        model: wbView.leftModules
                        delegate: Rectangle {
                            id: lDelegate
                            required property string modelData
                            required property int index
                            width: leftList.width
                            implicitHeight: 38
                            radius: 6
                            color: lItemMouse.containsMouse ? (theme ? theme.hover : "#26262e") : (theme ? theme.surfaceAlt : "#222228")
                            border.width: 1
                            border.color: theme ? theme.border : "#303036"

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 8
                                anchors.rightMargin: 8
                                spacing: 8

                                Text { text: "≡"; font.pixelSize: 13; color: theme ? theme.muted : "#666666" }
                                Text { text: wbView.getModuleIcon(lDelegate.modelData); font.pixelSize: 13; color: theme ? theme.accent : "#cba6f7" }
                                Text {
                                    Layout.fillWidth: true
                                    text: lDelegate.modelData
                                    font.pixelSize: 11
                                    font.bold: true
                                    color: theme ? theme.text : "#ffffff"
                                    elide: Text.ElideRight
                                }

                                // Move Up
                                Text {
                                    visible: lDelegate.index > 0
                                    text: "▲"
                                    font.pixelSize: 10
                                    color: upLMouse.containsMouse ? (theme ? theme.accent : "#cba6f7") : (theme ? theme.muted : "#888888")
                                    MouseArea {
                                        id: upLMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            var arr = wbView.leftModules.slice();
                                            var tmp = arr[lDelegate.index - 1];
                                            arr[lDelegate.index - 1] = arr[lDelegate.index];
                                            arr[lDelegate.index] = tmp;
                                            wbView.leftModules = arr;
                                            wbView.isModified = true;
                                        }
                                    }
                                }

                                // Move Down
                                Text {
                                    visible: lDelegate.index < wbView.leftModules.length - 1
                                    text: "▼"
                                    font.pixelSize: 10
                                    color: dnLMouse.containsMouse ? (theme ? theme.accent : "#cba6f7") : (theme ? theme.muted : "#888888")
                                    MouseArea {
                                        id: dnLMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            var arr = wbView.leftModules.slice();
                                            var tmp = arr[lDelegate.index + 1];
                                            arr[lDelegate.index + 1] = arr[lDelegate.index];
                                            arr[lDelegate.index] = tmp;
                                            wbView.leftModules = arr;
                                            wbView.isModified = true;
                                        }
                                    }
                                }

                                // Move to Center ->
                                Text {
                                    text: "→"
                                    font.pixelSize: 11
                                    font.bold: true
                                    color: toCMouse.containsMouse ? (theme ? theme.info : "#89b4fa") : (theme ? theme.muted : "#666666")
                                    MouseArea {
                                        id: toCMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            var mod = lDelegate.modelData;
                                            var lArr = wbView.leftModules.slice();
                                            lArr.splice(lDelegate.index, 1);
                                            var cArr = wbView.centerModules.slice();
                                            cArr.push(mod);
                                            wbView.leftModules = lArr;
                                            wbView.centerModules = cArr;
                                            wbView.isModified = true;
                                        }
                                    }
                                }

                                // Edit Module Source in Default Editor
                                Text {
                                    text: ""
                                    font.pixelSize: 11
                                    color: editLMouse.containsMouse ? (theme ? theme.accent : "#cba6f7") : (theme ? theme.muted : "#777777")
                                    MouseArea {
                                        id: editLMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            if (backend) backend.editWaybarModule(lDelegate.modelData);
                                        }
                                    }
                                }

                                // Delete from column
                                Text {
                                    text: "✕"
                                    font.pixelSize: 10
                                    color: delLMouse.containsMouse ? (theme ? theme.bad : "#f38ba8") : (theme ? theme.muted : "#777777")
                                    MouseArea {
                                        id: delLMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            var arr = wbView.leftModules.slice();
                                            arr.splice(lDelegate.index, 1);
                                            wbView.leftModules = arr;
                                            wbView.isModified = true;
                                        }
                                    }
                                }
                            }

                            MouseArea {
                                id: lItemMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                acceptedButtons: Qt.RightButton
                                onClicked: function(mouse) {
                                    if (mouse.button === Qt.RightButton) {
                                        lContextMenu.popup();
                                    }
                                }
                            }

                            Menu {
                                id: lContextMenu
                                MenuItem {
                                    text: "Move to Center (→)"
                                    onTriggered: {
                                        var mod = lDelegate.modelData;
                                        var lArr = wbView.leftModules.slice();
                                        lArr.splice(lDelegate.index, 1);
                                        var cArr = wbView.centerModules.slice();
                                        cArr.push(mod);
                                        wbView.leftModules = lArr;
                                        wbView.centerModules = cArr;
                                        wbView.isModified = true;
                                    }
                                }
                                MenuItem {
                                    text: "Move to Right (→→)"
                                    onTriggered: {
                                        var mod = lDelegate.modelData;
                                        var lArr = wbView.leftModules.slice();
                                        lArr.splice(lDelegate.index, 1);
                                        var rArr = wbView.rightModules.slice();
                                        rArr.push(mod);
                                        wbView.leftModules = lArr;
                                        wbView.rightModules = rArr;
                                        wbView.isModified = true;
                                    }
                                }
                                MenuItem {
                                    text: "Open definition in Editor"
                                    onTriggered: {
                                        if (backend) backend.editWaybarModule(lDelegate.modelData);
                                    }
                                }
                                MenuItem {
                                    text: "Remove from Waybar"
                                    onTriggered: {
                                        var arr = wbView.leftModules.slice();
                                        arr.splice(lDelegate.index, 1);
                                        wbView.leftModules = arr;
                                        wbView.isModified = true;
                                    }
                                }
                            }
                        }
                    }

                    // + Add Module button
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 32
                        radius: 6
                        color: addLMouse.containsMouse ? (theme ? theme.hover : "#282830") : "transparent"
                        border.width: 1
                        border.color: theme ? theme.border : "#35353d"

                        Text {
                            anchors.centerIn: parent
                            text: "+ Add Module"
                            font.pixelSize: 11
                            font.bold: true
                            color: theme ? theme.accent : "#cba6f7"
                        }

                        MouseArea {
                            id: addLMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                wbView.addColumnTarget = "left";
                                wbView.moduleSearchQuery = "";
                                wbView.showAddModal = true;
                            }
                        }
                    }
                }
            }

            // ==================== COLUMN 2: CENTER (modules-center) ====================
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: 8
                color: theme ? theme.surface : "#1c1c20"
                border.width: 1
                border.color: theme ? theme.border : "#303036"

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 8

                    // Header
                    RowLayout {
                        Layout.fillWidth: true
                        Text { text: "Center"; font.pixelSize: 13; font.bold: true; color: theme ? theme.text : "#ffffff" }
                        Rectangle {
                            implicitWidth: centerCount.implicitWidth + 10
                            implicitHeight: 18
                            radius: 9
                            color: theme ? theme.surfaceAlt : "#24242a"
                            Text { id: centerCount; anchors.centerIn: parent; text: wbView.centerModules.length; font.pixelSize: 10; color: theme ? theme.muted : "#888888" }
                        }
                        Item { Layout.fillWidth: true }
                        Text {
                            text: "Reset"
                            font.pixelSize: 11
                            color: resetCMouse.containsMouse ? (theme ? theme.accent : "#cba6f7") : (theme ? theme.muted : "#888888")
                            MouseArea {
                                id: resetCMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (backend && backend.waybarLayout) {
                                        wbView.centerModules = (backend.waybarLayout.modules_center || []).slice();
                                    }
                                }
                            }
                        }
                    }

                    // List
                    ListView {
                        id: centerList
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        spacing: 6
                        model: wbView.centerModules
                        delegate: Rectangle {
                            id: cDelegate
                            required property string modelData
                            required property int index
                            width: centerList.width
                            implicitHeight: 38
                            radius: 6
                            color: cItemMouse.containsMouse ? (theme ? theme.hover : "#26262e") : (theme ? theme.surfaceAlt : "#222228")
                            border.width: 1
                            border.color: theme ? theme.border : "#303036"

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 8
                                anchors.rightMargin: 8
                                spacing: 8

                                Text { text: "≡"; font.pixelSize: 13; color: theme ? theme.muted : "#666666" }
                                Text { text: wbView.getModuleIcon(cDelegate.modelData); font.pixelSize: 13; color: theme ? theme.accent : "#cba6f7" }
                                Text {
                                    Layout.fillWidth: true
                                    text: cDelegate.modelData
                                    font.pixelSize: 11
                                    font.bold: true
                                    color: theme ? theme.text : "#ffffff"
                                    elide: Text.ElideRight
                                }

                                // Move Left <-
                                Text {
                                    text: "←"
                                    font.pixelSize: 11
                                    font.bold: true
                                    color: toLMouse.containsMouse ? (theme ? theme.info : "#89b4fa") : (theme ? theme.muted : "#666666")
                                    MouseArea {
                                        id: toLMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            var mod = cDelegate.modelData;
                                            var cArr = wbView.centerModules.slice();
                                            cArr.splice(cDelegate.index, 1);
                                            var lArr = wbView.leftModules.slice();
                                            lArr.push(mod);
                                            wbView.centerModules = cArr;
                                            wbView.leftModules = lArr;
                                            wbView.isModified = true;
                                        }
                                    }
                                }

                                // Move Up
                                Text {
                                    visible: cDelegate.index > 0
                                    text: "▲"
                                    font.pixelSize: 10
                                    color: upCMouse.containsMouse ? (theme ? theme.accent : "#cba6f7") : (theme ? theme.muted : "#888888")
                                    MouseArea {
                                        id: upCMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            var arr = wbView.centerModules.slice();
                                            var tmp = arr[cDelegate.index - 1];
                                            arr[cDelegate.index - 1] = arr[cDelegate.index];
                                            arr[cDelegate.index] = tmp;
                                            wbView.centerModules = arr;
                                            wbView.isModified = true;
                                        }
                                    }
                                }

                                // Move Down
                                Text {
                                    visible: cDelegate.index < wbView.centerModules.length - 1
                                    text: "▼"
                                    font.pixelSize: 10
                                    color: dnCMouse.containsMouse ? (theme ? theme.accent : "#cba6f7") : (theme ? theme.muted : "#888888")
                                    MouseArea {
                                        id: dnCMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            var arr = wbView.centerModules.slice();
                                            var tmp = arr[cDelegate.index + 1];
                                            arr[cDelegate.index + 1] = arr[cDelegate.index];
                                            arr[cDelegate.index] = tmp;
                                            wbView.centerModules = arr;
                                            wbView.isModified = true;
                                        }
                                    }
                                }

                                // Move Right ->
                                Text {
                                    text: "→"
                                    font.pixelSize: 11
                                    font.bold: true
                                    color: toRMouse.containsMouse ? (theme ? theme.info : "#89b4fa") : (theme ? theme.muted : "#666666")
                                    MouseArea {
                                        id: toRMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            var mod = cDelegate.modelData;
                                            var cArr = wbView.centerModules.slice();
                                            cArr.splice(cDelegate.index, 1);
                                            var rArr = wbView.rightModules.slice();
                                            rArr.push(mod);
                                            wbView.centerModules = cArr;
                                            wbView.rightModules = rArr;
                                            wbView.isModified = true;
                                        }
                                    }
                                }

                                // Edit Module Source in Default Editor
                                Text {
                                    text: ""
                                    font.pixelSize: 11
                                    color: editCMouse.containsMouse ? (theme ? theme.accent : "#cba6f7") : (theme ? theme.muted : "#777777")
                                    MouseArea {
                                        id: editCMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            if (backend) backend.editWaybarModule(cDelegate.modelData);
                                        }
                                    }
                                }

                                // Delete from column
                                Text {
                                    text: "✕"
                                    font.pixelSize: 10
                                    color: delCMouse.containsMouse ? (theme ? theme.bad : "#f38ba8") : (theme ? theme.muted : "#777777")
                                    MouseArea {
                                        id: delCMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            var arr = wbView.centerModules.slice();
                                            arr.splice(cDelegate.index, 1);
                                            wbView.centerModules = arr;
                                            wbView.isModified = true;
                                        }
                                    }
                                }
                            }

                            MouseArea {
                                id: cItemMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                acceptedButtons: Qt.RightButton
                                onClicked: function(mouse) {
                                    if (mouse.button === Qt.RightButton) {
                                        cContextMenu.popup();
                                    }
                                }
                            }

                            Menu {
                                id: cContextMenu
                                MenuItem {
                                    text: "Move to Left (←)"
                                    onTriggered: {
                                        var mod = cDelegate.modelData;
                                        var cArr = wbView.centerModules.slice();
                                        cArr.splice(cDelegate.index, 1);
                                        var lArr = wbView.leftModules.slice();
                                        lArr.push(mod);
                                        wbView.centerModules = cArr;
                                        wbView.leftModules = lArr;
                                        wbView.isModified = true;
                                    }
                                }
                                MenuItem {
                                    text: "Move to Right (→)"
                                    onTriggered: {
                                        var mod = cDelegate.modelData;
                                        var cArr = wbView.centerModules.slice();
                                        cArr.splice(cDelegate.index, 1);
                                        var rArr = wbView.rightModules.slice();
                                        rArr.push(mod);
                                        wbView.centerModules = cArr;
                                        wbView.rightModules = rArr;
                                        wbView.isModified = true;
                                    }
                                }
                                MenuItem {
                                    text: "Open definition in Editor"
                                    onTriggered: {
                                        if (backend) backend.editWaybarModule(cDelegate.modelData);
                                    }
                                }
                                MenuItem {
                                    text: "Remove from Waybar"
                                    onTriggered: {
                                        var arr = wbView.centerModules.slice();
                                        arr.splice(cDelegate.index, 1);
                                        wbView.centerModules = arr;
                                        wbView.isModified = true;
                                    }
                                }
                            }
                        }
                    }

                    // + Add Module button
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 32
                        radius: 6
                        color: addCMouse.containsMouse ? (theme ? theme.hover : "#282830") : "transparent"
                        border.width: 1
                        border.color: theme ? theme.border : "#35353d"

                        Text {
                            anchors.centerIn: parent
                            text: "+ Add Module"
                            font.pixelSize: 11
                            font.bold: true
                            color: theme ? theme.accent : "#cba6f7"
                        }

                        MouseArea {
                            id: addCMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                wbView.addColumnTarget = "center";
                                wbView.moduleSearchQuery = "";
                                wbView.showAddModal = true;
                            }
                        }
                    }
                }
            }

            // ==================== COLUMN 3: END (modules-right) ====================
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: 8
                color: theme ? theme.surface : "#1c1c20"
                border.width: 1
                border.color: theme ? theme.border : "#303036"

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 8

                    // Header
                    RowLayout {
                        Layout.fillWidth: true
                        Text { text: "End"; font.pixelSize: 13; font.bold: true; color: theme ? theme.text : "#ffffff" }
                        Rectangle {
                            implicitWidth: rightCount.implicitWidth + 10
                            implicitHeight: 18
                            radius: 9
                            color: theme ? theme.surfaceAlt : "#24242a"
                            Text { id: rightCount; anchors.centerIn: parent; text: wbView.rightModules.length; font.pixelSize: 10; color: theme ? theme.muted : "#888888" }
                        }
                        Item { Layout.fillWidth: true }
                        Text {
                            text: "Reset"
                            font.pixelSize: 11
                            color: resetRMouse.containsMouse ? (theme ? theme.accent : "#cba6f7") : (theme ? theme.muted : "#888888")
                            MouseArea {
                                id: resetRMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (backend && backend.waybarLayout) {
                                        wbView.rightModules = (backend.waybarLayout.modules_right || []).slice();
                                    }
                                }
                            }
                        }
                    }

                    // List
                    ListView {
                        id: rightList
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        spacing: 6
                        model: wbView.rightModules
                        delegate: Rectangle {
                            id: rDelegate
                            required property string modelData
                            required property int index
                            width: rightList.width
                            implicitHeight: 38
                            radius: 6
                            color: rItemMouse.containsMouse ? (theme ? theme.hover : "#26262e") : (theme ? theme.surfaceAlt : "#222228")
                            border.width: 1
                            border.color: theme ? theme.border : "#303036"

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 8
                                anchors.rightMargin: 8
                                spacing: 8

                                Text { text: "≡"; font.pixelSize: 13; color: theme ? theme.muted : "#666666" }
                                Text { text: wbView.getModuleIcon(rDelegate.modelData); font.pixelSize: 13; color: theme ? theme.accent : "#cba6f7" }
                                Text {
                                    Layout.fillWidth: true
                                    text: rDelegate.modelData
                                    font.pixelSize: 11
                                    font.bold: true
                                    color: theme ? theme.text : "#ffffff"
                                    elide: Text.ElideRight
                                }

                                // Move Left <-
                                Text {
                                    text: "←"
                                    font.pixelSize: 11
                                    font.bold: true
                                    color: toLFromRMouse.containsMouse ? (theme ? theme.info : "#89b4fa") : (theme ? theme.muted : "#666666")
                                    MouseArea {
                                        id: toLFromRMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            var mod = rDelegate.modelData;
                                            var rArr = wbView.rightModules.slice();
                                            rArr.splice(rDelegate.index, 1);
                                            var cArr = wbView.centerModules.slice();
                                            cArr.push(mod);
                                            wbView.rightModules = rArr;
                                            wbView.centerModules = cArr;
                                            wbView.isModified = true;
                                        }
                                    }
                                }

                                // Move Up
                                Text {
                                    visible: rDelegate.index > 0
                                    text: "▲"
                                    font.pixelSize: 10
                                    color: upRMouse.containsMouse ? (theme ? theme.accent : "#cba6f7") : (theme ? theme.muted : "#888888")
                                    MouseArea {
                                        id: upRMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            var arr = wbView.rightModules.slice();
                                            var tmp = arr[rDelegate.index - 1];
                                            arr[rDelegate.index - 1] = arr[rDelegate.index];
                                            arr[rDelegate.index] = tmp;
                                            wbView.rightModules = arr;
                                            wbView.isModified = true;
                                        }
                                    }
                                }

                                // Move Down
                                Text {
                                    visible: rDelegate.index < wbView.rightModules.length - 1
                                    text: "▼"
                                    font.pixelSize: 10
                                    color: dnRMouse.containsMouse ? (theme ? theme.accent : "#cba6f7") : (theme ? theme.muted : "#888888")
                                    MouseArea {
                                        id: dnRMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            var arr = wbView.rightModules.slice();
                                            var tmp = arr[rDelegate.index + 1];
                                            arr[rDelegate.index + 1] = arr[rDelegate.index];
                                            arr[rDelegate.index] = tmp;
                                            wbView.rightModules = arr;
                                            wbView.isModified = true;
                                        }
                                    }
                                }

                                // Edit Module Source in Default Editor
                                Text {
                                    text: ""
                                    font.pixelSize: 11
                                    color: editRMouse.containsMouse ? (theme ? theme.accent : "#cba6f7") : (theme ? theme.muted : "#777777")
                                    MouseArea {
                                        id: editRMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            if (backend) backend.editWaybarModule(rDelegate.modelData);
                                        }
                                    }
                                }

                                // Delete from column
                                Text {
                                    text: "✕"
                                    font.pixelSize: 10
                                    color: delRMouse.containsMouse ? (theme ? theme.bad : "#f38ba8") : (theme ? theme.muted : "#777777")
                                    MouseArea {
                                        id: delRMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            var arr = wbView.rightModules.slice();
                                            arr.splice(rDelegate.index, 1);
                                            wbView.rightModules = arr;
                                            wbView.isModified = true;
                                        }
                                    }
                                }
                            }

                            MouseArea {
                                id: rItemMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                acceptedButtons: Qt.RightButton
                                onClicked: function(mouse) {
                                    if (mouse.button === Qt.RightButton) {
                                        rContextMenu.popup();
                                    }
                                }
                            }

                            Menu {
                                id: rContextMenu
                                MenuItem {
                                    text: "Move to Center (←)"
                                    onTriggered: {
                                        var mod = rDelegate.modelData;
                                        var rArr = wbView.rightModules.slice();
                                        rArr.splice(rDelegate.index, 1);
                                        var cArr = wbView.centerModules.slice();
                                        cArr.push(mod);
                                        wbView.rightModules = rArr;
                                        wbView.centerModules = cArr;
                                        wbView.isModified = true;
                                    }
                                }
                                MenuItem {
                                    text: "Move to Left (←←)"
                                    onTriggered: {
                                        var mod = rDelegate.modelData;
                                        var rArr = wbView.rightModules.slice();
                                        rArr.splice(rDelegate.index, 1);
                                        var lArr = wbView.leftModules.slice();
                                        lArr.push(mod);
                                        wbView.rightModules = rArr;
                                        wbView.leftModules = lArr;
                                        wbView.isModified = true;
                                    }
                                }
                                MenuItem {
                                    text: "Open definition in Editor"
                                    onTriggered: {
                                        if (backend) backend.editWaybarModule(rDelegate.modelData);
                                    }
                                }
                                MenuItem {
                                    text: "Remove from Waybar"
                                    onTriggered: {
                                        var arr = wbView.rightModules.slice();
                                        arr.splice(rDelegate.index, 1);
                                        wbView.rightModules = arr;
                                        wbView.isModified = true;
                                    }
                                }
                            }
                        }
                    }

                    // + Add Module button
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 32
                        radius: 6
                        color: addRMouse.containsMouse ? (theme ? theme.hover : "#282830") : "transparent"
                        border.width: 1
                        border.color: theme ? theme.border : "#35353d"

                        Text {
                            anchors.centerIn: parent
                            text: "+ Add Module"
                            font.pixelSize: 11
                            font.bold: true
                            color: theme ? theme.accent : "#cba6f7"
                        }

                        MouseArea {
                            id: addRMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                wbView.addColumnTarget = "right";
                                wbView.moduleSearchQuery = "";
                                wbView.showAddModal = true;
                            }
                        }
                    }
                }
            }
        }

        // Bottom Action Bar
        ActionButtons {
            Layout.fillWidth: true
            theme: wbView.theme
            backend: wbView.backend
            targetFile: backend && backend.waybarLayout ? (backend.configHome + "/hypr/waybar/configs/" + backend.waybarLayout.name) : ""
            canApply: true
            canRevert: true
            canEdit: true
            onApplyClicked: {
                if (backend && backend.waybarLayout) {
                    var targetName = backend.waybarLayout.name;
                    // If saving a system preset, auto-clone to [Custom-#] to protect system file
                    if (!backend.waybarLayout.is_custom) {
                        targetName = backend.waybarLayout.suggested_clone || ("[Custom-1]-" + backend.waybarLayout.name);
                    }
                    backend.saveWaybarLayout(targetName, wbView.leftModules, wbView.centerModules, wbView.rightModules, true);
                    wbView.isModified = false;
                }
            }
            onValidateClicked: {
                if (backend && backend.waybarLayout) {
                    backend.validateWaybarSyntax(backend.waybarLayout.path);
                }
            }
            onRevertClicked: {
                wbView.syncFromBackend();
            }
        }
    }

    // Modal: Clone Configuration
    Rectangle {
        visible: wbView.showCloneModal
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.7)
        z: 100

        MouseArea { anchors.fill: parent; onClicked: {} } // block clicks

        Rectangle {
            width: 480
            implicitHeight: cloneCol.implicitHeight + 36
            anchors.centerIn: parent
            radius: 10
            color: theme ? theme.surface : "#1c1c20"
            border.width: 1
            border.color: theme ? theme.accent : "#cba6f7"

            ColumnLayout {
                id: cloneCol
                anchors.fill: parent
                anchors.margins: 18
                spacing: 12

                Text {
                    text: "󰑍 Clone Waybar Configuration"
                    font.pixelSize: 15
                    font.bold: true
                    color: theme ? theme.text : "#ffffff"
                }

                Text {
                    Layout.fillWidth: true
                    text: "System configurations are protected. Cloned files are named '[Custom-#]-<name>' so your customized layouts are sorted together at the top of the menu. You can customize the name below:"
                    font.pixelSize: 11
                    color: theme ? theme.muted : "#888888"
                    wrapMode: Text.WordWrap
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 34
                    radius: 6
                    color: theme ? theme.surfaceAlt : "#24242a"
                    border.width: 1
                    border.color: theme ? theme.accent : "#cba6f7"

                    TextInput {
                        id: cloneInput
                        anchors.fill: parent
                        anchors.margins: 8
                        text: wbView.customCloneName
                        font.family: theme ? theme.fontFamily : "monospace"
                        font.pixelSize: 12
                        color: theme ? theme.text : "#ffffff"
                        onTextChanged: wbView.customCloneName = text
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    Item { Layout.fillWidth: true }

                    Rectangle {
                        implicitWidth: 80
                        implicitHeight: 30
                        radius: 6
                        color: cancelCloneM.containsMouse ? (theme ? theme.hover : "#2c2c34") : "transparent"
                        border.width: 1
                        border.color: theme ? theme.border : "#35353d"
                        Text { anchors.centerIn: parent; text: "Cancel"; font.pixelSize: 11; color: theme ? theme.text : "#ffffff" }
                        MouseArea {
                            id: cancelCloneM
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: wbView.showCloneModal = false
                        }
                    }

                    Rectangle {
                        implicitWidth: 110
                        implicitHeight: 30
                        radius: 6
                        color: theme ? theme.accent : "#cba6f7"
                        Text { anchors.centerIn: parent; text: "Clone & Edit"; font.pixelSize: 11; font.bold: true; color: theme ? theme.accentInk : "#111111" }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (backend && backend.waybarLayout) {
                                    backend.cloneWaybarConfig(backend.waybarLayout.name, wbView.customCloneName);
                                }
                                wbView.showCloneModal = false;
                            }
                        }
                    }
                }
            }
        }
    }

    // Modal: Add Module to Column
    Rectangle {
        visible: wbView.showAddModal
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.7)
        z: 100

        MouseArea { anchors.fill: parent; onClicked: {} } // block clicks

        Rectangle {
            width: 520
            height: 420
            anchors.centerIn: parent
            radius: 10
            color: theme ? theme.surface : "#1c1c20"
            border.width: 1
            border.color: theme ? theme.accent : "#cba6f7"

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 18
                spacing: 12

                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        text: "+ Add Module to " + (wbView.addColumnTarget === "left" ? "Start" : (wbView.addColumnTarget === "center" ? "Center" : "End"))
                        font.pixelSize: 14
                        font.bold: true
                        color: theme ? theme.text : "#ffffff"
                    }
                    Item { Layout.fillWidth: true }
                    Text {
                        text: "✕"
                        font.pixelSize: 12
                        color: theme ? theme.muted : "#888888"
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: wbView.showAddModal = false
                        }
                    }
                }

                // Search Box
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 32
                    radius: 6
                    color: theme ? theme.surfaceAlt : "#24242a"
                    border.width: 1
                    border.color: theme ? theme.border : "#35353d"

                    TextInput {
                        anchors.fill: parent
                        anchors.margins: 6
                        font.family: theme ? theme.fontFamily : "sans-serif"
                        font.pixelSize: 11
                        color: theme ? theme.text : "#ffffff"
                        onTextChanged: wbView.moduleSearchQuery = text

                        Text {
                            anchors.fill: parent
                            text: "Filter available modules..."
                            font: parent.font
                            color: theme ? theme.muted : "#666666"
                            visible: !parent.text && !parent.activeFocus
                        }
                    }
                }

                // Available Modules List
                ScrollView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true

                    Flow {
                        width: parent.width
                        spacing: 8

                        Repeater {
                            model: {
                                var all = backend && backend.waybarLayout ? (backend.waybarLayout.available_modules || []) : [];
                                if (!wbView.moduleSearchQuery) return all;
                                var q = wbView.moduleSearchQuery.toLowerCase().trim();
                                return all.filter(function(m) { return m.toLowerCase().indexOf(q) !== -1; });
                            }

                            delegate: Rectangle {
                                required property string modelData
                                implicitWidth: addPillText.implicitWidth + 20
                                implicitHeight: 30
                                radius: 6
                                color: addPillM.containsMouse ? (theme ? theme.hover : "#2e2e38") : (theme ? theme.surfaceAlt : "#222228")
                                border.width: 1
                                border.color: theme ? theme.border : "#35353d"

                                RowLayout {
                                    id: addPillText
                                    anchors.centerIn: parent
                                    spacing: 6
                                    Text { text: wbView.getModuleIcon(modelData); font.pixelSize: 11; color: theme ? theme.accent : "#cba6f7" }
                                    Text { text: modelData; font.pixelSize: 11; font.bold: true; color: theme ? theme.text : "#ffffff" }
                                }

                                MouseArea {
                                    id: addPillM
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        var mod = modelData;
                                        if (wbView.addColumnTarget === "left") {
                                            var arr = wbView.leftModules.slice();
                                            arr.push(mod);
                                            wbView.leftModules = arr;
                                        } else if (wbView.addColumnTarget === "center") {
                                            var arr = wbView.centerModules.slice();
                                            arr.push(mod);
                                            wbView.centerModules = arr;
                                        } else {
                                            var arr = wbView.rightModules.slice();
                                            arr.push(mod);
                                            wbView.rightModules = arr;
                                        }
                                        wbView.isModified = true;
                                        wbView.showAddModal = false;
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
