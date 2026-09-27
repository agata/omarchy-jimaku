import QtQuick
import Quickshell
import "." as App
ShellRoot {
  function check(ok, message) { if (!ok) { console.error(message); Qt.exit(1) } }
  App.CaptionPanel { id: panel }
  Timer { interval: 100; running: true; onTriggered: {
    panel.compact = true
    panel.displayedCaption = "字幕の見た目をここで調整できます。"
    panel.appearanceOpen = true
    panel.revealToolbar()
  } }
  Timer { interval: 3100; running: true; onTriggered: {
    check(!panel.toolbarShown && !panel.appearanceOpen, "Appearance panel did not hide after inactivity")
    panel.pointerMoved(30, 30)
    check(panel.toolbarShown, "Movement did not restore toolbar")
    panel.moreOpen = true
    panel.pointerLeft()
  } }
  Timer { interval: 5900; running: true; onTriggered: {
    check(!panel.toolbarShown && !panel.moreOpen, "More panel did not hide after leaving")
    panel.pointerMoved(40, 40)
    panel.appearanceOpen = true
  } }
  Timer { interval: 7800; running: true; onTriggered: panel.pointerMoved(50, 50) }
  Timer { interval: 8800; running: true; onTriggered: {
    check(panel.toolbarShown && panel.appearanceOpen, "Movement did not extend visibility")
  } }
  Timer { interval: 10600; running: true; onTriggered: {
    check(!panel.toolbarShown && !panel.appearanceOpen, "Panel did not hide after movement stopped")
    console.log("TOOLBAR_AUTO_HIDE_PASSED"); Qt.quit()
  } }
}
