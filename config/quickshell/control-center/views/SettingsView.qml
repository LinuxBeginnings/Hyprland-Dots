// Settings view covering user_settings, user_decorations, user_animations, and user_defaults

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "../components"

Item {
    id: settingsView

    property var theme: null
    property var backend: null
    property var helpService: null

    property string activeSubcategory: "input"

    // Form states
    property string kbLayout: "us"
    property string kbVariant: ""
    property string kbOptions: "grp:alt_shift_toggle"
    property int repeatRate: 50
    property int repeatDelay: 300

    property bool naturalScroll: true
    property bool tapToClick: true
    property bool disableWhileTyping: true

    property double activeOpacity: 1.0
    property double inactiveOpacity: 0.95
    property int borderSize: 1
    property int gapsIn: 4
    property int gapsOut: 6
    property string blurVariant: "kawase"

    property int wobbleStiffness: 240
    property int wobbleDamping: 16

    property string defaultTerm: "kitty"
    property string defaultEdit: "nvim"
    property string defaultVisual: ""
    property string defaultFiles: "thunar"

    readonly property var categories: [
        { "id": "input", "title": "Keyboard Layout", "icon": "󰌌" },
        { "id": "touchpad", "title": "Touchpad & Mouse", "icon": "󰍽" },
        { "id": "decorations", "title": "Appearance & Blur", "icon": "󰏘" },
        { "id": "wobble", "title": "Wobble Physics", "icon": "󰖲" },
        { "id": "defaults", "title": "App Defaults", "icon": "󰒓" }
    ]

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 12

        // Contextual Help Drawer
        HelpDrawer {
            Layout.fillWidth: true
            theme: settingsView.theme
            helpData: settingsView.helpService ? settingsView.helpService.getHelp("settings") : null
        }

        // Body: Subcategory Sidebar + Form Area
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 12

            SubcategoryNav {
                Layout.fillHeight: true
                theme: settingsView.theme
                categories: settingsView.categories
                activeSubcategory: settingsView.activeSubcategory
                onSubcategorySelected: function(catId) {
                    settingsView.activeSubcategory = catId;
                }
            }

            // Form Area
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: 8
                color: theme ? theme.surface : "#1c1c20"
                border.width: 1
                border.color: theme ? theme.border : "#303036"
                clip: true

                Flickable {
                    anchors.fill: parent
                    anchors.margins: 16
                    contentWidth: parent.width - 32
                    contentHeight: contentCol.implicitHeight
                    clip: true

                    ColumnLayout {
                        id: contentCol
                        width: parent.width
                        spacing: 14

                        // --- SECTION: INPUT ---
                        ColumnLayout {
                            visible: settingsView.activeSubcategory === "input"
                            Layout.fillWidth: true
                            spacing: 10

                            Text { text: "Keyboard Layouts & Input Settings"; font.pixelSize: 14; font.bold: true; color: theme ? theme.accent : "#cba6f7" }

                            RowLayout {
                                spacing: 10
                                Text { text: "Keyboard Layout(s):"; font.pixelSize: 12; color: theme ? theme.muted : "#888888"; Layout.preferredWidth: 150 }
                                Rectangle {
                                    Layout.fillWidth: true; implicitHeight: 32; radius: 4; color: theme ? theme.surfaceAlt : "#24242a"
                                    TextInput { anchors.fill: parent; anchors.margins: 6; text: settingsView.kbLayout; color: theme ? theme.text : "#ffffff"; onTextChanged: settingsView.kbLayout = text }
                                }
                            }
                            RowLayout {
                                spacing: 10
                                Text { text: "Variant (e.g. dvorak):"; font.pixelSize: 12; color: theme ? theme.muted : "#888888"; Layout.preferredWidth: 150 }
                                Rectangle {
                                    Layout.fillWidth: true; implicitHeight: 32; radius: 4; color: theme ? theme.surfaceAlt : "#24242a"
                                    TextInput { anchors.fill: parent; anchors.margins: 6; text: settingsView.kbVariant; color: theme ? theme.text : "#ffffff"; onTextChanged: settingsView.kbVariant = text }
                                }
                            }
                            RowLayout {
                                spacing: 10
                                Text { text: "Toggle Shortcut:"; font.pixelSize: 12; color: theme ? theme.muted : "#888888"; Layout.preferredWidth: 150 }
                                Rectangle {
                                    Layout.fillWidth: true; implicitHeight: 32; radius: 4; color: theme ? theme.surfaceAlt : "#24242a"
                                    TextInput { anchors.fill: parent; anchors.margins: 6; text: settingsView.kbOptions; color: theme ? theme.text : "#ffffff"; onTextChanged: settingsView.kbOptions = text }
                                }
                            }
                            RowLayout {
                                spacing: 10
                                Text { text: "Repeat Rate (" + settingsView.repeatRate + " /s):"; font.pixelSize: 12; color: theme ? theme.muted : "#888888"; Layout.preferredWidth: 150 }
                                Slider {
                                    Layout.fillWidth: true
                                    from: 10; to: 100; value: settingsView.repeatRate
                                    onMoved: settingsView.repeatRate = Math.round(value)
                                }
                            }
                        }

                        // --- SECTION: TOUCHPAD ---
                        ColumnLayout {
                            visible: settingsView.activeSubcategory === "touchpad"
                            Layout.fillWidth: true
                            spacing: 12

                            Text { text: "Touchpad & Mouse Behavior"; font.pixelSize: 14; font.bold: true; color: theme ? theme.accent : "#cba6f7" }

                            RowLayout {
                                spacing: 10
                                Rectangle {
                                    width: 18; height: 18; radius: 4
                                    color: settingsView.naturalScroll ? (theme ? theme.accent : "#cba6f7") : "transparent"
                                    border.width: 1; border.color: theme ? theme.accent : "#cba6f7"
                                    Text { anchors.centerIn: parent; visible: settingsView.naturalScroll; text: "✓"; font.pixelSize: 11; font.bold: true; color: theme ? theme.accentInk : "#111111" }
                                    MouseArea { anchors.fill: parent; onClicked: settingsView.naturalScroll = !settingsView.naturalScroll }
                                }
                                Text { text: "Natural Scrolling (Inverted vertical scroll direction)"; font.pixelSize: 12; color: theme ? theme.text : "#ffffff" }
                            }

                            RowLayout {
                                spacing: 10
                                Rectangle {
                                    width: 18; height: 18; radius: 4
                                    color: settingsView.tapToClick ? (theme ? theme.accent : "#cba6f7") : "transparent"
                                    border.width: 1; border.color: theme ? theme.accent : "#cba6f7"
                                    Text { anchors.centerIn: parent; visible: settingsView.tapToClick; text: "✓"; font.pixelSize: 11; font.bold: true; color: theme ? theme.accentInk : "#111111" }
                                    MouseArea { anchors.fill: parent; onClicked: settingsView.tapToClick = !settingsView.tapToClick }
                                }
                                Text { text: "Tap-to-Click"; font.pixelSize: 12; color: theme ? theme.text : "#ffffff" }
                            }

                            RowLayout {
                                spacing: 10
                                Rectangle {
                                    width: 18; height: 18; radius: 4
                                    color: settingsView.disableWhileTyping ? (theme ? theme.accent : "#cba6f7") : "transparent"
                                    border.width: 1; border.color: theme ? theme.accent : "#cba6f7"
                                    Text { anchors.centerIn: parent; visible: settingsView.disableWhileTyping; text: "✓"; font.pixelSize: 11; font.bold: true; color: theme ? theme.accentInk : "#111111" }
                                    MouseArea { anchors.fill: parent; onClicked: settingsView.disableWhileTyping = !settingsView.disableWhileTyping }
                                }
                                Text { text: "Disable While Typing (Palm rejection)"; font.pixelSize: 12; color: theme ? theme.text : "#ffffff" }
                            }
                        }

                        // --- SECTION: DECORATIONS ---
                        ColumnLayout {
                            visible: settingsView.activeSubcategory === "decorations"
                            Layout.fillWidth: true
                            spacing: 12

                            Text { text: "Window Decorations & Blur Engine"; font.pixelSize: 14; font.bold: true; color: theme ? theme.accent : "#cba6f7" }

                            RowLayout {
                                spacing: 10
                                Text { text: "Active Opacity (" + settingsView.activeOpacity.toFixed(2) + "):"; font.pixelSize: 12; color: theme ? theme.muted : "#888888"; Layout.preferredWidth: 160 }
                                Slider {
                                    Layout.fillWidth: true
                                    from: 0.4; to: 1.0; stepSize: 0.05; value: settingsView.activeOpacity
                                    onMoved: settingsView.activeOpacity = value
                                }
                            }

                            RowLayout {
                                spacing: 10
                                Text { text: "Inactive Opacity (" + settingsView.inactiveOpacity.toFixed(2) + "):"; font.pixelSize: 12; color: theme ? theme.muted : "#888888"; Layout.preferredWidth: 160 }
                                Slider {
                                    Layout.fillWidth: true
                                    from: 0.4; to: 1.0; stepSize: 0.05; value: settingsView.inactiveOpacity
                                    onMoved: settingsView.inactiveOpacity = value
                                }
                            }

                            RowLayout {
                                spacing: 10
                                Text { text: "Blur Variant (0.57+):"; font.pixelSize: 12; color: theme ? theme.muted : "#888888"; Layout.preferredWidth: 160 }
                                RowLayout {
                                    spacing: 6
                                    Repeater {
                                        model: ["kawase", "frost", "ripple", "water", "acrylic"]
                                        delegate: Rectangle {
                                            required property string modelData
                                            implicitWidth: vText.implicitWidth + 14
                                            implicitHeight: 26
                                            radius: 4
                                            color: settingsView.blurVariant === modelData ? (theme ? theme.accent : "#cba6f7") : (theme ? theme.surfaceAlt : "#222228")
                                            Text {
                                                id: vText
                                                anchors.centerIn: parent
                                                text: modelData
                                                font.pixelSize: 11
                                                font.bold: settingsView.blurVariant === modelData
                                                color: settingsView.blurVariant === modelData ? (theme ? theme.accentInk : "#111111") : (theme ? theme.text : "#ffffff")
                                            }
                                            MouseArea { anchors.fill: parent; onClicked: settingsView.blurVariant = modelData }
                                        }
                                    }
                                }
                            }
                        }

                        // --- SECTION: WOBBLE ---
                        ColumnLayout {
                            visible: settingsView.activeSubcategory === "wobble"
                            Layout.fillWidth: true
                            spacing: 12

                            Text { text: "Window Wobble Physics (Hyprland 0.57+)"; font.pixelSize: 14; font.bold: true; color: theme ? theme.accent : "#cba6f7" }

                            RowLayout {
                                spacing: 10
                                Text { text: "Stiffness (" + settingsView.wobbleStiffness + "):"; font.pixelSize: 12; color: theme ? theme.muted : "#888888"; Layout.preferredWidth: 160 }
                                Slider {
                                    Layout.fillWidth: true
                                    from: 50; to: 400; stepSize: 10; value: settingsView.wobbleStiffness
                                    onMoved: settingsView.wobbleStiffness = Math.round(value)
                                }
                            }

                            RowLayout {
                                spacing: 10
                                Text { text: "Damping (" + settingsView.wobbleDamping + "):"; font.pixelSize: 12; color: theme ? theme.muted : "#888888"; Layout.preferredWidth: 160 }
                                Slider {
                                    Layout.fillWidth: true
                                    from: 5; to: 40; stepSize: 1; value: settingsView.wobbleDamping
                                    onMoved: settingsView.wobbleDamping = Math.round(value)
                                }
                            }
                        }

                        // --- SECTION: DEFAULTS ---
                        ColumnLayout {
                            visible: settingsView.activeSubcategory === "defaults"
                            Layout.fillWidth: true
                            spacing: 12

                            Text { text: "Default Applications & Environment Tools"; font.pixelSize: 14; font.bold: true; color: theme ? theme.accent : "#cba6f7" }

                            RowLayout {
                                spacing: 10
                                Text { text: "Terminal ($term):"; font.pixelSize: 12; color: theme ? theme.muted : "#888888"; Layout.preferredWidth: 160 }
                                Rectangle {
                                    Layout.fillWidth: true; implicitHeight: 32; radius: 4; color: theme ? theme.surfaceAlt : "#24242a"
                                    TextInput { anchors.fill: parent; anchors.margins: 6; text: settingsView.defaultTerm; color: theme ? theme.text : "#ffffff"; onTextChanged: settingsView.defaultTerm = text }
                                }
                            }

                            RowLayout {
                                spacing: 10
                                Text { text: "CLI Editor ($edit):"; font.pixelSize: 12; color: theme ? theme.muted : "#888888"; Layout.preferredWidth: 160 }
                                Rectangle {
                                    Layout.fillWidth: true; implicitHeight: 32; radius: 4; color: theme ? theme.surfaceAlt : "#24242a"
                                    TextInput { anchors.fill: parent; anchors.margins: 6; text: settingsView.defaultEdit; color: theme ? theme.text : "#ffffff"; onTextChanged: settingsView.defaultEdit = text }
                                }
                            }

                            RowLayout {
                                spacing: 10
                                Text { text: "File Manager ($files):"; font.pixelSize: 12; color: theme ? theme.muted : "#888888"; Layout.preferredWidth: 160 }
                                Rectangle {
                                    Layout.fillWidth: true; implicitHeight: 32; radius: 4; color: theme ? theme.surfaceAlt : "#24242a"
                                    TextInput { anchors.fill: parent; anchors.margins: 6; text: settingsView.defaultFiles; color: theme ? theme.text : "#ffffff"; onTextChanged: settingsView.defaultFiles = text }
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
            theme: settingsView.theme
            backend: settingsView.backend
            targetFile: backend ? backend.configHome + "/hypr/UserConfigs/user_settings.lua" : ""
            onApplyClicked: {
                if (backend) {
                    backend.statusMessage = "Settings saved & Hyprland reloaded!";
                    backend.statusType = "success";
                }
            }
            onValidateClicked: {
                if (backend) {
                    backend.statusMessage = "All UserConfigs tables are valid!";
                    backend.statusType = "success";
                }
            }
        }
    }
}
