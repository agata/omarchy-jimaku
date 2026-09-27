import QtQuick
import Quickshell
import "." as App

ShellRoot {
  property int smallSize: 0
  property int wideSize: 0
  function check(ok, message) { if (!ok) { console.error(message); Qt.exit(1) } }
  App.CaptionPanel {
    id: panel
    opened: true
    compact: true
  }
  Timer { interval: 100; running: true; onTriggered: {
    panel.captionContent.Window.window.width = 500; panel.captionContent.Window.window.height = 300
    panel.displayedCaption = "ウィンドウに合わせて、字幕の大きさを自動で調整します。"
  } }
  Timer { interval: 300; running: true; onTriggered: {
    smallSize = panel.textSize
    panel.captionContent.Window.window.width = 1000
    panel.captionContent.Window.window.height = 400
  } }
  Timer { interval: 500; running: true; onTriggered: {
    check(panel.textSize > smallSize, "Wider window must enlarge captions")
    wideSize = panel.textSize
    panel.displayedCaption = "短い字幕。"
    panel.toolbarShown = false
    check(panel.textSize === wideSize, "Sentence and toolbar must not change font size")
    panel.textSizeChoice = 0
    check(panel.textSize < wideSize, "Small preference must reduce font")
    panel.textSizeChoice = 2
    check(panel.textSize > wideSize, "Large preference must enlarge font")
    panel.textSizeChoice = 1
    panel.captionContent.Window.window.height = 150
  } }
  Timer { interval: 700; running: true; onTriggered: {
    check(panel.textSize < wideSize && panel.textSize >= 18, "Short window must constrain font")
    panel.displayedCaption = "あ".repeat(90)
    panel.captionContent.Window.window.width = 420
  } }
  Timer { interval: 1000; running: true; onTriggered: {
    check(panel.displayedCaption.length < 90 && panel.cueQueue.length > 0, "Resize must preserve overflow in queue")
    check(panel.displayedCaption + panel.cueQueue.map(function(c) {return c.text}).join("") === "あ".repeat(90), "Resize must not lose text")
    panel.clearCaptions()
    panel.captionContent.Window.window.width = 800; panel.captionContent.Window.window.height = 260
    panel.displayedCaption = "ウィンドウに合わせて、字幕の大きさを自動で調整します。"
    panel.toolbarShown = true
  } }
  Timer { interval: 1250; running: true; onTriggered: {
    panel.captionContent.grabToImage(function(result) {
      result.saveToFile(Quickshell.env("JIMAKU_TEST_SCREENSHOT"))
      console.log("AUTO_FONT_SIZE_PASSED")
      Qt.quit()
    })
  } }
}
