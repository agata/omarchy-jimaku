import QtQuick
import Quickshell
import "." as App
ShellRoot {
  function check(ok, message) { if (!ok) { console.error(message); Qt.exit(1) } }
  App.CaptionPanel { id: panel }
  Timer { interval: 50; running: true; onTriggered: {
    panel.applyDisplayMode("realtime")
    panel.appendTranslation("最初の字幕。")
    check(panel.displayUntil - panel.displayStartedAt === 800, "Realtime minimum incorrect")
  } }
  Timer { interval: 200; running: true; onTriggered: {
    panel.appendTranslation("古い字幕。さらに古い字幕。最新の字幕。")
    check(panel.displayedCaption === "最初の字幕。", "Replaced before minimum")
  } }
  Timer { interval: 1050; running: true; onTriggered: {
    check(panel.displayedCaption === "古い字幕。", "Small burst lost a sentence")
    panel.clearCaptions()
    panel.appendTranslation("句読点がまだない字幕")
  } }
  Timer { interval: 3000; running: true; onTriggered: {
    check(panel.displayedCaption === "句読点がまだない字幕", "Realtime fallback too slow")
    panel.applyDisplayMode("readable")
    panel.clearCaptions()
    panel.appendTranslation("読む時間を確保します。")
    check(panel.displayUntil - panel.displayStartedAt >= 2200, "Readable minimum incorrect")
    panel.uiJapanese = false
    check(panel.tr("設定") === "Settings", "English UI translation missing")
    panel.uiJapanese = true
    check(panel.tr("設定") === "設定", "Japanese UI translation missing")
    console.log("MODES_LOCALIZATION_PASSED"); Qt.quit()
  } }
}
