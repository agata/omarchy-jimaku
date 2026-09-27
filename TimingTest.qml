import QtQuick
import Quickshell
import "." as App
ShellRoot {
  function check(ok, message) { if (!ok) { console.error(message); Qt.exit(1) } }
  App.CaptionPanel { id: panel; displayMode: "readable" }
  property double originalDeadline: 0
  Timer { interval: 50; running: true; onTriggered: {
    panel.appendTranslation("これは長めの字幕ですので通常であればゆっくりと数秒かけて表示されます。")
    originalDeadline = panel.displayUntil
    check(panel.captionChanges === 1, "First cue missing")
  } }
  Timer { interval: 200; running: true; onTriggered: {
    panel.appendTranslation("二番目の字幕です。三番目の字幕です。四番目の字幕です。五番目の字幕です。六番目の字幕です。七番目の字幕です。")
    check(panel.displayUntil < originalDeadline, "Current cue was not shortened")
  } }
  Timer { interval: 1300; running: true; onTriggered: {
    check(panel.captionChanges >= 2, "Burst did not advance current cue early")
    panel.clearCaptions()
    panel.appendTranslation("単独の短い字幕です。")
    check(panel.displayUntil - panel.displayStartedAt === 2200, "Normal timing did not recover")
  } }
  Timer { interval: 1600; running: true; onTriggered: {
    check(panel.captionChanges === 1, "Recovery cue advanced too soon")
    console.log("LIVE_TIMING_ADJUSTMENT_PASSED")
    Qt.quit()
  } }
}
