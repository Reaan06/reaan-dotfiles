import QtQml
import Quickshell
QtObject {
    readonly property string home: Quickshell.env("HOME") || ""
    readonly property string configHome: Quickshell.env("QS_CONFIG_HOME") || Quickshell.env("XDG_CONFIG_HOME") || home + "/.config"
    readonly property string runtimeDir: Quickshell.env("QS_RUNTIME_DIR") || Quickshell.env("XDG_RUNTIME_DIR") || "/tmp"
    readonly property string wallpaperRoot: Quickshell.env("QS_WALLPAPER_ROOT") || (Quickshell.env("XDG_PICTURES_DIR") || home + "/Pictures") + "/wallpapers"
    readonly property string scriptsDir: configHome + "/scripts"
}
