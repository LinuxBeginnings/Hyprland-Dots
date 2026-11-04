//@ pragma UseQApplication
//@ pragma Env QT_QUICK_CONTROLS_STYLE=Basic

import "./modules/overview/"
import "./services/"
import "./common/"
import "./common/functions/"
import "./common/widgets/"

import QtQuick
import Quickshell
import Quickshell.Hyprland

ShellRoot {
    Overview {}

    // Singletons are lazily loaded, so the first read can happen before the
    // palette file is there. Kick it once the root exists.
    Component.onCompleted: MaterialThemeLoader.reapplyTheme()
}
