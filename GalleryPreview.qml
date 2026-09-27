import QtQuick
import Quickshell
import "." as App

// Render the production UI with synthetic data. Never start the backend.
ShellRoot {
  property string scene: Quickshell.env("JIMAKU_PREVIEW_SCENE") || "captions"
  App.CaptionPanel {
    id: panel
    opened: true
    Component.onCompleted: {
      applySettings({key_ready: true, ui_language: "en", display_mode: "realtime",
        languages: [{code: "en", label: "English"}, {code: "ja", label: "日本語"}],
        system_language: "en", target_preference: "auto", target_language: "en", system_fallback: false})
      ready = true
      applySources([{id: "sample", app: "Chromium", label: "Chromium", active: true}])
      showSettings = scene === "settings"
      compact = scene === "captions" || scene === "toolbar"
    }
  }
  // Item captures omit QQuickWindow's clear color. Reproduce that same color behind it.
  Rectangle {
    parent: panel.captionContent
    anchors.fill: parent
    z: -1
    color: panel.captionWindow.color
  }
  Timer {
    interval: 100; running: true
    onTriggered: {
      panel.captionContent.Window.window.width = panel.compact ? 920 : 520
      panel.captionContent.Window.window.height = scene === "settings" ? 640 : panel.compact ? 280 : 300
    }
  }
  Timer {
    interval: 350; running: true
    onTriggered: {
      panel.displayedCaption = "A new language.\nThe same conversation."
      panel.toolbarShown = scene === "toolbar"
    }
  }
  Timer {
    interval: 600; running: true
    onTriggered: panel.captionContent.grabToImage(function(result) {
      if (!result.saveToFile(Quickshell.env("JIMAKU_TEST_SCREENSHOT"))) {
        console.error("Could not save preview"); Qt.exit(1); return
      }
      console.log("GALLERY_PREVIEW_PASSED " + scene)
      Qt.quit()
    })
  }
}
