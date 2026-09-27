import QtQuick
import Quickshell
import "." as App
ShellRoot {
  function check(ok, message) { if (!ok) { console.error(message); Qt.exit(1) } }
  App.CaptionPanel { id: panel; displayMode: "readable"; Component.onCompleted: open("{}") }
  Timer { interval: 900; running: true; onTriggered: {
    panel.errorText = ""; panel.showSettings = false; panel.compact = true
    panel.clearCaptions(); panel.appendTranslation("この説明はまだ")
    panel.revealToolbar()
  } }
  Timer { interval: 2000; running: true; onTriggered: {
    check(!(panel.displayedCaption !== ""), "A short receive gap split the sentence")
    panel.appendTranslation("続きます")
  } }
  Timer { interval: 3800; running: true; onTriggered: {
    check(!(panel.toolbarShown), "Toolbar did not auto-hide")
    check(!(panel.displayedCaption !== ""), "Caption split before punctuation")
    panel.appendTranslation("、次の文章に移ります。")
    check(!(panel.displayedCaption !== "この説明はまだ続きます、"), "Comma boundary missing")
    panel.boldText = true; panel.warmText = true
    panel.pointerMoved(20,20)
  } }
  Timer { interval: 4200; running: true; onTriggered: {
    check(!(!panel.toolbarShown), "Toolbar did not reappear")
    panel.captionContent.grabToImage(function(result) {
      result.saveToFile(Quickshell.env("JIMAKU_TEST_SCREENSHOT"))
      console.log("TOOLBAR_AND_PUNCTUATION_PASSED")
      panel.clearCaptions(); panel.appendTranslation("句読点が来ないときの最終手段")
    })
  } }
  Timer { interval: 10800; running: true; onTriggered: {
    check(panel.displayedCaption === "句読点が来ないときの最終手段", "Six-second fallback did not display")
    console.log("FALLBACK_PASSED")
    panel.close(); Qt.quit()
  } }
}
