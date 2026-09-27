import QtQuick
import Quickshell

ShellRoot {
  CaptionPanel {
    id: panel
    Component.onCompleted: open("{}")
    onOpenedChanged: if (!opened) Qt.quit()
  }
}
