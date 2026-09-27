import QtQuick
import Quickshell
import "." as App
ShellRoot {
  function check(ok, message) { if (!ok) { console.error(message); Qt.exit(1) } }
  App.CaptionPanel { id: panel; Component.onCompleted: open("{}") }
  Timer { interval: 900; running: true; onTriggered: {
    check(panel.ready && panel.targetLanguage === "ja" && panel.targetPreference === "auto", "OS default was not Japanese")
    check(panel.languageItems.length === 14, "Language options missing")
    panel.showSettings = true
    panel.selectLanguage(panel.languageItems.findIndex(function(row) { return row.code === "fr" }))
    check(panel.languageSaving && !panel.canStart, "Start not blocked while saving")
  } }
  Timer { interval: 1400; running: true; onTriggered: {
    check(!panel.languageSaving && panel.targetLanguage === "fr" && panel.targetPreference === "fr", "Saved selection not acknowledged")
    panel.state = "live"
    panel.selectLanguage(0)
    check(!panel.languageSaving && panel.targetPreference === "fr", "Language changed during translation")
    panel.state = "idle"
    panel.selectLanguage(0)
  } }
  Timer { interval: 1900; running: true; onTriggered: {
    check(panel.targetLanguage === "ja" && panel.targetPreference === "auto", "OS mode not restored")
    panel.sourceError = ""
    panel.captionContent.grabToImage(function(result) {
      result.saveToFile(Quickshell.env("JIMAKU_TEST_SCREENSHOT"))
      console.log("LANGUAGE_SELECTION_PASSED")
      panel.close(); Qt.quit()
    })
  } }
}
