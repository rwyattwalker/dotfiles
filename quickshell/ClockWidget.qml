// ClockWidget.qml
import QtQuick

Rectangle {

    implicitWidth: 150
    anchors.centerIn: parent

    Text {
        anchors.centerIn: parent
        text: Time.time
        color: Colors.white
        font.family: "JetBrainsMono Nerd Font"
    }
}
