// Colors.qml
pragma Singleton

import QtQuick
import Quickshell

Singleton {
    // Base colors
    readonly property color bg: "#1a1b26"
    readonly property color bgDark: "#16161e"
    readonly property color bgDarkest: "#0c0e14"

    // General UI colors
    readonly property color background: "#1a1b26"
    readonly property color foreground: "#c0caf5"

    readonly property color selectionBackground: "#283457"
    readonly property color selectionForeground: "#c0caf5"

    readonly property color url: "#73daca"

    readonly property color cursor: "#c0caf5"
    readonly property color cursorText: "#1a1b26"

    // Tabs
    readonly property color activeTabBackground: "#7aa2f7"
    readonly property color activeTabForeground: "#16161e"

    readonly property color inactiveTabBackground: "#292e42"
    readonly property color inactiveTabForeground: "#545c7e"

    readonly property color tabBarBackground: "#15161e"

    // Window borders
    readonly property color activeBorder: "#7aa2f7"
    readonly property color inactiveBorder: "#292e42"

    // Normal terminal colors
    readonly property color black: "#15161e"
    readonly property color red: "#f7768e"
    readonly property color green: "#9ece6a"
    readonly property color yellow: "#e0af68"
    readonly property color blue: "#7aa2f7"
    readonly property color magenta: "#bb9af7"
    readonly property color cyan: "#7dcfff"
    readonly property color white: "#a9b1d6"

    // Bright terminal colors
    readonly property color brightBlack: "#414868"
    readonly property color brightRed: "#ff899d"
    readonly property color brightGreen: "#9fe044"
    readonly property color brightYellow: "#faba4a"
    readonly property color brightBlue: "#8db0ff"
    readonly property color brightMagenta: "#c7a9ff"
    readonly property color brightCyan: "#a4daff"
    readonly property color brightWhite: "#c0caf5"

    // Extended colors
    readonly property color peach: "#ff9e64"
    readonly property color deepRed: "#db4b4b"

    // Raw terminal palette aliases
    readonly property color color0: black
    readonly property color color1: red
    readonly property color color2: green
    readonly property color color3: yellow
    readonly property color color4: blue
    readonly property color color5: magenta
    readonly property color color6: cyan
    readonly property color color7: white

    readonly property color color8: brightBlack
    readonly property color color9: brightRed
    readonly property color color10: brightGreen
    readonly property color color11: brightYellow
    readonly property color color12: brightBlue
    readonly property color color13: brightMagenta
    readonly property color color14: brightCyan
    readonly property color color15: brightWhite

    readonly property color color16: peach
    readonly property color color17: deepRed
}

