import QtQuick
import Quickshell
import "." as App

ShellRoot {
  function check(ok, message) { if (!ok) { console.error(message); Qt.exit(1) } }
  App.CaptionPanel {
    id: panel; displayMode: "readable"
    Component.onCompleted: open("{}")
  }
  Timer {
    interval: 900; running: true
    onTriggered: {
      check(!(!panel.ready), "Backend did not start")
      panel.showSettings = false
      panel.begin(true)
    }
  }
  Timer {
    interval: 5900; running: true
    onTriggered: {
      check(!(panel.captionChanges < 1 || panel.captionChanges > 5 || !panel.displayedCaption.length || !panel.compact), "Caption mode did not receive a cue")
      panel.captionContent.grabToImage(function(result) {
        result.saveToFile(Quickshell.env("JIMAKU_TEST_SCREENSHOT"))
        panel.close()
        console.log("UI_DEMO_PASSED; cue changes=" + panel.captionChanges)
        Qt.quit()
      })
    }
  }
}
