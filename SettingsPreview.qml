import QtQuick
import Quickshell
import "." as App
ShellRoot {
  App.CaptionPanel {
    id: panel
    opened: true
    ready: true
    keyReady: true
    showSettings: true
    Component.onCompleted: applySettings({key_ready:true,ui_language:Quickshell.env("JIMAKU_PREVIEW_LANGUAGE") || "ja",display_mode:"realtime",languages:[{code:"ja",label:"日本語"},{code:"en",label:"English"}],system_language:"ja",target_preference:"auto",target_language:"ja",system_fallback:false})
  }
  Timer { interval: 100; running: true; onTriggered: panel.captionContent.Window.window.height = 640 }
  Timer { interval: 300; running: true; onTriggered: {
    panel.captionContent.grabToImage(function(result) {
      result.saveToFile(Quickshell.env("JIMAKU_TEST_SCREENSHOT"))
      console.log("SETTINGS_PREVIEW_PASSED"); Qt.quit()
    })
  } }
}
