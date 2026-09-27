import QtQuick
import Quickshell
import qs.Ui

BarWidget {
  id: root
  moduleName: "io.github.agata.jimaku"
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight
  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "󰨖"
    tooltipText: Qt.locale().name.indexOf("ja") === 0 ? "Jimaku · 翻訳字幕" : "Jimaku · Translated captions"
    onPressed: function(button) {
      if (button === Qt.LeftButton)
        Quickshell.execDetached(["omarchy-shell", "shell", "toggle", root.moduleName, "{}"])
    }
  }
}
