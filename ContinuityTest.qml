import QtQuick
import Quickshell
import "." as App
ShellRoot {
  function check(ok, message) { if (!ok) { console.error(message); Qt.exit(1) } }
  App.CaptionPanel { id: panel }
  Timer { interval: 50; running: true; onTriggered: panel.appendTranslation("この字幕は途中で") }
  Timer { interval: 800; running: true; onTriggered: {
    check(panel.displayedCaption === "", "Premature 650ms split returned")
    panel.appendTranslation("切らずに表示します")
  } }
  Timer { interval: 1200; running: true; onTriggered: {
    panel.appendTranslation("。")
    check(panel.displayedCaption === "この字幕は途中で切らずに表示します。", "Sentence not preserved")
    panel.appendTranslation("」")
    check(panel.displayedCaption.endsWith("。」") && panel.cueQueue.length === 0, "Late closer became isolated cue")
    panel.clearCaptions()
    panel.appendTranslation("句読点のない文も待ちすぎません")
  } }
  Timer { interval: 3200; running: true; onTriggered: {
    check(panel.displayedCaption === "句読点のない文も待ちすぎません", "Fallback did not run")
    panel.appendTranslation("。次の文は続いています")
    check(panel.displayedCaption.endsWith("。"), "Late punctuation was not attached")
    check(panel.pendingText === "次の文は続いています", "Continuation lost")
    console.log("REALTIME_CONTINUITY_PASSED"); Qt.quit()
  } }
}
