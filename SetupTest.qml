import QtQuick
import Quickshell
import "." as App
ShellRoot {
  App.CaptionPanel { id: panel; Component.onCompleted: open("{}") }
  Timer { interval: 1400; running: true; onTriggered: {
    if (panel.ready || panel.errorText.indexOf("setup.sh") < 0 || panel.canStart) {
      console.error("Missing runtime must show setup instructions and disable start")
      Qt.exit(1)
      return
    }
    console.log("MISSING_RUNTIME_PASSED")
    panel.close(); Qt.quit()
  } }
}
