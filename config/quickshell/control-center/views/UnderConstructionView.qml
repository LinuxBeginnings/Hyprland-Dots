// Under Construction view for Phase 2 components (Waybar Editor and upcoming features)

import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import "../components"

Item {
    id: ucView

    property var theme: null
    property var backend: null
    property var helpService: null
    property string activeTab: "waybar"

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 14

        HelpDrawer {
            Layout.fillWidth: true
            theme: ucView.theme
            helpData: ucView.helpService ? ucView.helpService.getHelp(ucView.activeTab) : null
        }

        ConstructionCard {
            Layout.fillWidth: true
            Layout.fillHeight: true
            theme: ucView.theme
            featureTitle: ucView.activeTab === "waybar" ? "Waybar Visual Editor" : "Feature Under Construction"
            phase: "Phase 2"
            note: ucView.activeTab === "waybar"
                ? "Full visual Waybar module layout arranger, style editor, and live CSS inspector is in development for Phase 2.\nIn the meantime, you can customize bar typography and scaling using the Waybar Font applet."
                : "This module is planned for an upcoming KoolDots release."
            quickActionText: ucView.activeTab === "waybar" ? "Open Waybar Font & Size Settings" : ""
            onQuickActionTriggered: {
                if (backend) {
                    launchWaybarFontProcess.command = [backend.configHome + "/hypr/scripts/WaybarFontSelector.sh"];
                    launchWaybarFontProcess.running = true;
                }
            }
        }
    }

    Process {
        id: launchWaybarFontProcess
    }
}
