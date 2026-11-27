// Main master layout coordinating TopNav, views, and ErrorModal

import QtQuick
import QtQuick.Layouts
import "components"
import "views"

Item {
    id: mainView

    property var theme: null
    property var backend: null
    property var helpService: null

    property string currentTab: "home"

    Rectangle {
        anchors.fill: parent
        color: theme ? theme.bg : "#141416"
        radius: 12
        border.width: 1
        border.color: theme ? theme.border : "#35353d"
        clip: true

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 12

            // Top Horizontal Navigation Bar
            TopNav {
                Layout.fillWidth: true
                theme: mainView.theme
                activeTab: mainView.currentTab
                onTabSelected: function(tabId) {
                    mainView.currentTab = tabId;
                }
            }

            // View Content Router
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                HomeView {
                    anchors.fill: parent
                    visible: mainView.currentTab === "home"
                    theme: mainView.theme
                    backend: mainView.backend
                    helpService: mainView.helpService
                    onSwitchTab: function(tabId) {
                        mainView.currentTab = tabId;
                    }
                }

                KeybindsView {
                    anchors.fill: parent
                    visible: mainView.currentTab === "keybinds"
                    theme: mainView.theme
                    backend: mainView.backend
                    helpService: mainView.helpService
                }

                SettingsView {
                    anchors.fill: parent
                    visible: mainView.currentTab === "settings"
                    theme: mainView.theme
                    backend: mainView.backend
                    helpService: mainView.helpService
                }

                WindowRulesView {
                    anchors.fill: parent
                    visible: mainView.currentTab === "rules"
                    theme: mainView.theme
                    backend: mainView.backend
                    helpService: mainView.helpService
                }

                StartupView {
                    anchors.fill: parent
                    visible: mainView.currentTab === "startup"
                    theme: mainView.theme
                    backend: mainView.backend
                    helpService: mainView.helpService
                }

                TogglesView {
                    anchors.fill: parent
                    visible: mainView.currentTab === "toggles"
                    theme: mainView.theme
                    backend: mainView.backend
                    helpService: mainView.helpService
                }

                MonitorsView {
                    anchors.fill: parent
                    visible: mainView.currentTab === "monitors"
                    theme: mainView.theme
                    backend: mainView.backend
                    helpService: mainView.helpService
                }

                UnderConstructionView {
                    anchors.fill: parent
                    visible: mainView.currentTab === "waybar" ||
                             (mainView.currentTab !== "home" &&
                              mainView.currentTab !== "keybinds" &&
                              mainView.currentTab !== "settings" &&
                              mainView.currentTab !== "rules" &&
                              mainView.currentTab !== "startup" &&
                              mainView.currentTab !== "toggles" &&
                              mainView.currentTab !== "monitors")
                    theme: mainView.theme
                    backend: mainView.backend
                    helpService: mainView.helpService
                    activeTab: mainView.currentTab
                }
            }
        }

        // Global Diagnostic / Error Modal
        ErrorModal {
            theme: mainView.theme
            backend: mainView.backend
        }
    }
}
