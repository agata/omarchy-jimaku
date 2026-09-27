import QtQuick
import Quickshell
import "." as App
ShellRoot {
  function check(ok, message) { if (!ok) { console.error(message); Qt.exit(1) } }
  App.CaptionPanel { id: panel; opened: true; ready: true; keyReady: true; targetLanguage: "ja" }
  Timer { interval: 100; running: true; onTriggered: {
    check(!panel.canStart, "Start enabled without audio")
    panel.applySources([{id:"1", app:"Chrome",label:"Chrome — Playback",active:true}])
    check(panel.selectedId === "1" && panel.canStart, "Single source was not selected")
    panel.applySources([{id:"1",app:"Chrome",label:"Chrome",active:true},{id:"2",app:"VLC",label:"VLC",active:true}])
    panel.selectedId = "2"
    panel.applySources([{id:"1",app:"Chrome",label:"Chrome",active:true},{id:"2",app:"VLC",label:"VLC",active:true}])
    check(panel.selectedId === "2", "Polling reset selection")
    panel.applySources([{id:"1",app:"Chrome",label:"Chrome",active:true},{id:"2",app:"VLC",label:"VLC",active:false}])
    check(panel.selectedId === "1" && panel.sourceItems.length === 1, "Inactive source not removed")
    panel.applySources([])
    check(!panel.canStart && panel.selectedId === "", "Stale selection survived disappearance")
    panel.applySources([{id:"1",app:"Chrome",label:"Chrome",active:true}])
  } }
  Timer { interval: 500; running: true; onTriggered: {
    panel.captionContent.grabToImage(function(result) {
      result.saveToFile(Quickshell.env("JIMAKU_TEST_SCREENSHOT"))
      console.log("SOURCE_SELECTION_PASSED")
      Qt.quit()
    })
  } }
}
