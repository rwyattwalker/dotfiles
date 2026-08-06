// Time.qml
pragma Singleton

import Quickshell
import QtQuick

Singleton {
  id: root
  readonly property string time: {
    Qt.formatTime(clock.date, "hh:mm")
  }

  SystemClock {
    id: clock
    precision: SystemClock.Minutes
  }
}
