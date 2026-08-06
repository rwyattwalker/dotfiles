// Bar.qml
import Quickshell
import Quickshell.Hyprland
import QtQuick

Scope {
    id: root

    property bool expanded: false
    property bool calendarVisible: false
    property int margin: 8

    GlobalShortcut {
        name: "toggle-bar"
        onPressed: root.expanded = !root.expanded
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: window

            required property var modelData

            screen: modelData
            color: "transparent"

            implicitWidth: background.width + margin
            implicitHeight: root.expanded ? background.height + margin : 8

            anchors {
                top: true
            }

            Rectangle {
                id: background

                anchors.horizontalCenter: parent.horizontalCenter

                width: 150
                height: 30

                // Leave only 8px visible when collapsed:
                // 30px pill height - 22px offset = 8px visible.
                y: root.expanded ? 4 : -22

                radius: 100
                color: Colors.background

                Behavior on y {
                    NumberAnimation {
                        duration: 200
                        easing.type: Easing.OutCubic
                    }
                }

                Behavior on width {
                    NumberAnimation {
                        duration: 200
                        easing.type: Easing.OutCubic
                    }
                }

                Behavior on height {
                    NumberAnimation {
                        duration: 200
                        easing.type: Easing.OutCubic
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    onClicked: mouse => {
                        if (mouse.button === Qt.RightButton) {
                            root.calendarVisible = !root.calendarVisible;
                            return;
                        }

                        root.expanded = !root.expanded;
                    }
                }

                ClockWidget {
                    anchors {
                        horizontalCenter: parent.horizontalCenter
                        top: parent.top
                    }
                }

            }
        }
    }
}
