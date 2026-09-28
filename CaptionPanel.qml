import QtQuick
import QtQuick.Controls as C
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "Captions.js" as Captions
import "Translations.js" as I18n

Item {
  id: root
  property var shell: null
  property var manifest: null
  property alias captionWindow: window
  property alias captionContent: surface
  property bool opened: false
  property bool ready: false
  property bool keyReady: false
  property bool uiJapanese: Qt.locale().name.indexOf("ja") === 0
  function tr(text) { return uiJapanese ? text : (I18n.english[text] || text) }
  property string displayMode: "realtime"
  property bool modeSaving: false
  function setDisplayMode(mode) {
    if (!ready || modeSaving) return
    modeSaving = true
    send({action: "set_display_mode", mode: mode})
  }
  function applyDisplayMode(mode) {
    displayMode = mode
    modeBox.currentIndex = mode === "realtime" ? 0 : 1
    if (cueTimer.running) {
      cueTimer.interval = Math.max(1, displayStartedAt + Captions.holdTime(displayedCaption, cueQueue.length, oldestWait(Date.now()), displayMode) - Date.now())
      displayUntil = Date.now() + cueTimer.interval
      cueTimer.restart()
    }
    if (pendingText.length) limitTimer.restart()
  }
  property var languageItems: []
  property string targetPreference: "auto"
  property string targetLanguage: ""
  property bool languageSaving: false
  property bool systemLanguageFallback: false
  function applySettings(e) {
    keyReady = e.key_ready
    if (e.ui_language) uiJapanese = e.ui_language === "ja"
    if (e.display_mode && e.display_mode !== displayMode) applyDisplayMode(e.display_mode)
    modeSaving = false
    if (e.languages) {
      let systemName = e.languages.find(function(row) { return row.code === e.system_language }).label
      languageItems = [{code: "auto", label: root.tr("OSに合わせる") + " (" + systemName + ")"}].concat(e.languages)
      targetPreference = e.target_preference
      targetLanguage = e.target_language
      systemLanguageFallback = e.system_fallback
      languageBox.currentIndex = languageItems.findIndex(function(row) { return row.code === root.targetPreference })
      languageSaving = false
    }
    if (!keyReady) { showSettings = true; compact = false }
  }
  function selectLanguage(index) {
    if (!ready || busy || languageSaving || index < 0 || index >= languageItems.length) return
    languageSaving = true
    errorText = ""
    send({action: "set_target", language: languageItems[index].code})
  }
  property bool showSettings: false
  property bool appearanceOpen: false
  property bool moreOpen: false
  property string selectedId: ""
  property string sourceError: ""
  readonly property var selectedSource: sourceItems.find(function(row) { return row.id === root.selectedId }) || null
  readonly property bool canStart: ready && keyReady && !languageSaving && targetLanguage !== "" && selectedSource !== null && !busy
  function applySources(items) {
    let active = items.filter(function(row) { return row.active !== false })
    let keep = active.some(function(row) { return row.id === root.selectedId })
    if (JSON.stringify(active) !== JSON.stringify(sourceItems)) sourceItems = active
    if (!keep) selectedId = active.length ? active[0].id : ""
    sourceBox.currentIndex = active.findIndex(function(row) { return row.id === root.selectedId })
    sourceError = ""
    refreshing = false
  }
  function stopAndReturn() {
    if (busy) send({action: "stop"})
    compact = false
  }
  property bool compact: false
  property bool toolbarShown: false
  property real pointerX: -10000
  property real pointerY: -10000
  function pointerMoved(x, y) {
    if (Math.abs(x - pointerX) < 1 && Math.abs(y - pointerY) < 1) return
    pointerX = x; pointerY = y
    revealToolbar()
  }
  property bool boldText: false
  property bool outlineText: true
  property bool warmText: false
  property int backgroundChoice: 0
  readonly property real subtitleOpacity: [1.0, 0.75, 0.0][backgroundChoice]
  onCompactChanged: {
    appearanceOpen = false; moreOpen = false
    if (compact) revealToolbar()
    else { toolbarShown = false; toolbarTimer.stop() }
  }
  function revealToolbar() {
    if (!compact) return
    toolbarShown = true
    toolbarTimer.restart()
  }
  function pointerLeft() {
    if (compact && toolbarShown) toolbarTimer.restart()
  }
  property string state: "idle"
  property string message: root.tr("動画を再生して、音声を選んでください。")
  property string errorText: ""
  property string pendingText: ""
  property string displayedCaption: ""
  property var cueQueue: []
  property int captionChanges: 0
  property double displayStartedAt: 0
  property double displayUntil: 0
  readonly property int cueLimit: Math.max(16, Math.min(60, Math.floor((window.width - 64) / textSize) * 2 - 4))
  property var sourceItems: []
  property int seconds: 0
  property real audioLevel: 0
  property bool delayed: false
  property bool refreshing: false
  property int textSizeChoice: 1
  // Geometry only: changing the sentence or revealing controls must not resize type.
  readonly property int textSize: Math.max(18, Math.floor(Math.min(72,
    (window.width - 52) / 16 * [0.85, 1.0, 1.2][textSizeChoice],
    (window.height - 52) / 4.2)))
  onCueLimitChanged: resizeCueTimer.restart()
  readonly property bool busy: state !== "idle"
  Loader { id: themeLoader; active: root.shell !== null; source: "ThemeBridge.qml" }
  readonly property color bg: themeLoader.item ? themeLoader.item.background : "#101923"
  readonly property color fg: themeLoader.item ? themeLoader.item.foreground : "#e6edf3"
  readonly property color muted: themeLoader.item ? themeLoader.item.muted : "#9caebb"
  readonly property color accent: themeLoader.item ? themeLoader.item.accent : "#89dfc6"
  readonly property color panelBg: Qt.tint(bg, Qt.rgba(fg.r, fg.g, fg.b, 0.06))
  readonly property color buttonBg: Qt.tint(bg, Qt.rgba(fg.r, fg.g, fg.b, 0.10))
  readonly property color hoverBg: Qt.tint(bg, Qt.rgba(fg.r, fg.g, fg.b, 0.18))
  readonly property color borderColor: Qt.tint(bg, Qt.rgba(fg.r, fg.g, fg.b, 0.28))
  readonly property color accentText: (accent.r * 0.299 + accent.g * 0.587 + accent.b * 0.114) > 0.55 ? "#101010" : "#ffffff"
  readonly property string folder: manifest && manifest.__sourceDir
    ? String(manifest.__sourceDir)
    : decodeURIComponent(Qt.resolvedUrl(".").toString().replace(/^file:\/\//, "")).replace(/\/$/, "")

  function open(payloadJson) {
    opened = true
    if (!worker.running) worker.running = true
    else if (ready && !busy) refresh()
  }
  function close() {
    opened = false
    if (busy) send({action: "stop"})
  }
  function send(value) {
    if (ready) worker.write(JSON.stringify(value) + "\n")
  }
  function diagnostics() {
    return JSON.stringify({ uiVersion: "0.9.2", opened: opened, ready: ready, state: state,
      keyReady: keyReady, sources: sourceItems.length, selectedId: selectedId, canStart: canStart, error: errorText, compact: compact, toolbarShown: toolbarShown,
      captionChanges: captionChanges, queuedCues: cueQueue.length, textSize: textSize, textSizeChoice: textSizeChoice,
      targetPreference: targetPreference, targetLanguage: targetLanguage, displayMode: displayMode, uiJapanese: uiJapanese, themed: themeLoader.item !== null, background: String(bg) })
  }
  function refresh() {
    if (!ready || refreshing || busy) return
    refreshing = true
    send({action: "sources"})
  }
  function begin(demo) {
    if (!ready || busy || (!demo && !canStart)) return
    showSettings = false
    compact = true
    errorText = ""
    state = demo ? "demo" : "connecting"
    send(demo ? {action: "demo"} : {action: "start", source: selectedId})
  }
  function clearCaptions() {
    limitTimer.stop()
    cueTimer.stop()
    clearTimer.stop()
    pendingText = ""
    cueQueue = []
    displayedCaption = ""
    captionChanges = 0
    displayStartedAt = 0
    displayUntil = 0
  }
  function appendTranslation(text) {
    // A closing mark can arrive in a later API delta; attach it to its own sentence.
    if (!pendingText.length) {
      let closing = Captions.leadingClosers(text)
      if (closing.length && (cueQueue.length || displayedCaption.length)) {
        if (cueQueue.length) {
          let updated = cueQueue.slice()
          let last = updated[updated.length - 1]
          updated[updated.length - 1] = {text: last.text + closing, queuedAt: last.queuedAt}
          cueQueue = updated
        } else displayedCaption += closing
        text = text.slice(closing.length)
      }
    }
    pendingText += text
    collectCues(false)
    if (pendingText.length) {
      if (!limitTimer.running) limitTimer.start()
    }
  }
  function collectCues(flush) {
    let result = Captions.extract(pendingText, cueLimit, flush)
    pendingText = result.rest
    // Bound latency after an unusually large burst; prefer the latest captions.
    let receivedAt = Date.now()
    cueQueue = cueQueue.concat(result.cues.map(function(text) {
      return { text: text, queuedAt: receivedAt }
    })).slice(-8)
    if (result.cues.length || !pendingText.length) limitTimer.stop()
    if (pendingText.length && !limitTimer.running) limitTimer.start()
    if (!cueTimer.running && cueQueue.length) showNextCue()
    else accelerateCurrentCue()
  }
  function showNextCue() {
    if (!cueQueue.length) { clearTimer.restart(); return }
    clearTimer.stop()
    // Small bursts are normal streaming, not a reason to discard sentence fragments.
    if (displayMode === "realtime" && (cueQueue.length >= 4 || oldestWait(Date.now()) >= 2400))
      cueQueue = cueQueue.slice(-2)
    let next = cueQueue[0]
    let smaller = Captions.extract(next.text, cueLimit, true).cues.map(function(text) {
      return { text: text, queuedAt: next.queuedAt }
    })
    cueQueue = smaller.concat(cueQueue.slice(1))
    displayedCaption = cueQueue[0].text
    cueQueue = cueQueue.slice(1)
    captionChanges++
    displayStartedAt = Date.now()
    cueTimer.interval = Captions.holdTime(displayedCaption, cueQueue.length, oldestWait(displayStartedAt), displayMode)
    displayUntil = displayStartedAt + cueTimer.interval
    cueTimer.restart()
  }
  function oldestWait(now) {
    return cueQueue.length ? Math.max(0, now - cueQueue[0].queuedAt) : 0
  }
  function accelerateCurrentCue() {
    if (!cueTimer.running || !cueQueue.length) return
    let now = Date.now()
    let due = Captions.nextDeadline(displayedCaption, cueQueue.length,
      oldestWait(now), displayStartedAt, displayUntil, displayMode)
    if (due >= displayUntil) return
    displayUntil = due
    cueTimer.interval = Math.max(1, due - now)
    cueTimer.restart()
  }
  function handle(line) {
    let e
    try { e = JSON.parse(line) } catch (_) { return }
    if (e.type === "ready") { ready = true; send({action: "settings"}); refresh() }
    else if (e.type === "sources") applySources(e.items)
    else if (e.type === "settings") applySettings(e)
    else if (e.type === "history_file") {
      if (!Qt.openUrlExternally(e.url)) errorText = root.tr("履歴ファイルを開けませんでした。")
    }
    else if (e.type === "status") {
      state = e.state; message = e.message
      if (state === "idle") { audioLevel = 0; collectCues(true); if (opened) refresh() }
    }
    else if (e.type === "error") {
      refreshing = false
      modeSaving = false
      if (e.operation === "set_display_mode") modeBox.currentIndex = root.displayMode === "realtime" ? 0 : 1
      if (e.operation === "set_target") {
        languageSaving = false
        languageBox.currentIndex = languageItems.findIndex(function(row) { return row.code === root.targetPreference })
      }
      if (e.operation === "sources") { sourceError = root.tr(e.message); sourceItems = []; selectedId = "" }
      else {
        errorText = root.tr(e.message); compact = false
        if (state === "connecting") state = "idle"
      }
    }
    else if (e.type === "notice") { message = e.message }
    else if (e.type === "reset") { clearCaptions(); seconds = 0; delayed = false }
    else if (e.type === "delta" && e.lane === "translation") appendTranslation(e.text)
    else if (e.type === "meter") { seconds = e.seconds; audioLevel = e.level; delayed = e.delayed }
  }

  Timer {
    interval: 1000; repeat: true
    running: root.opened && root.ready && worker.running && !root.busy
    onTriggered: root.refresh()
  }
  Timer { id: limitTimer; interval: root.displayMode === "realtime" ? 1800 : 6000; onTriggered: root.collectCues(true) }
  // After a resize, preserve overflow as subsequent cues instead of shrinking text.
  Timer {
    id: resizeCueTimer
    interval: 150
    onTriggered: {
      let hardLimit = Math.max(root.cueLimit + 12, Math.ceil(root.cueLimit * 1.5))
      if (Array.from(root.displayedCaption).length <= hardLimit) return
      let pieces = Captions.extract(root.displayedCaption, root.cueLimit, true).cues
      root.displayedCaption = pieces.shift() || ""
      let queuedAt = root.displayStartedAt || Date.now()
      root.cueQueue = pieces.map(function(text) { return {text: text, queuedAt: queuedAt} }).concat(root.cueQueue)
      clearTimer.stop()
      if (!cueTimer.running && root.cueQueue.length) {
        root.displayStartedAt = Date.now()
        cueTimer.interval = Captions.holdTime(root.displayedCaption, root.cueQueue.length, root.oldestWait(Date.now()), root.displayMode)
        root.displayUntil = root.displayStartedAt + cueTimer.interval
        cueTimer.restart()
      } else root.accelerateCurrentCue()
    }
  }
  Timer {
    interval: 100; repeat: true
    running: cueTimer.running && root.cueQueue.length > 0
    onTriggered: root.accelerateCurrentCue()
  }
  Timer { id: cueTimer; onTriggered: root.showNextCue() }
  Timer {
    id: clearTimer
    interval: 2500
    onTriggered: if (!root.cueQueue.length && !cueTimer.running) root.displayedCaption = ""
  }

  Timer {
    id: toolbarTimer
    interval: 2500
    onTriggered: {
      root.toolbarShown = false
      root.appearanceOpen = false
      root.moreOpen = false
    }
  }

  Process {
    id: worker
    command: ["/usr/bin/python3", "-u", root.folder + "/lib/launch.py"]
    stdinEnabled: true
    stdout: SplitParser { onRead: function(data) { root.handle(data) } }
    stderr: StdioCollector { }
    onExited: function(code, status) {
      root.ready = false
      root.compact = false
      root.state = "idle"
      root.refreshing = false
      root.languageSaving = false
      root.modeSaving = false
      if (root.opened) root.errorText = code === 78
        ? root.tr("初回セットアップが必要です。プラグインフォルダで bash setup.sh を実行してください。")
        : root.tr("字幕サービスが終了しました。ウィンドウを開き直してください。")
    }
  }

  component Label: Text {
    color: root.fg
    textFormat: Text.PlainText
    font.pixelSize: 14
    wrapMode: Text.Wrap
  }
  component Button: C.Button {
    id: control
    property bool primary: false
    implicitHeight: 36
    leftPadding: 14; rightPadding: 14
    contentItem: Text {
      text: control.text
      color: control.enabled ? (control.primary ? root.accentText : root.fg) : root.muted
      font.pixelSize: 13
      horizontalAlignment: Text.AlignHCenter
      verticalAlignment: Text.AlignVCenter
    }
    background: Rectangle {
      radius: 7
      color: control.primary && control.enabled ? root.accent : control.down ? root.borderColor : control.hovered ? root.hoverBg : root.buttonBg
      border.color: control.activeFocus ? root.accent : root.borderColor
    }
  }

  FloatingWindow {
    id: window
    visible: root.opened
    title: "Jimaku — Live captions"
    color: root.compact ? Qt.rgba(0.035, 0.05, 0.07, root.subtitleOpacity) : root.bg
    implicitWidth: 500
    implicitHeight: 300
    minimumSize: Qt.size(420, root.compact ? 150 : (root.showSettings ? 640 : 280))
    onVisibleChanged: if (!visible && root.opened) root.close()

    Item {
      id: surface
      anchors.fill: parent

    Shortcut { sequence: "Escape"; onActivated: root.compact = false }
    Shortcut { sequence: "Ctrl+Space"; onActivated: root.stopAndReturn() }

    ColumnLayout {
      id: content
      anchors.fill: parent
      anchors.margins: 22
      spacing: 12
      RowLayout {
        visible: !root.compact
        Layout.fillWidth: true
        Item { Layout.fillWidth: true }
        Button { text: root.showSettings ? root.tr("戻る") : root.tr("設定"); onClicked: root.showSettings = !root.showSettings }
        Button { text: "×"; onClicked: root.close(); C.ToolTip.text: root.tr("閉じる"); C.ToolTip.visible: hovered }
      }
      Item { visible: !root.compact && !root.showSettings; Layout.fillHeight: true }
      ColumnLayout {
        visible: !root.compact && !root.showSettings
        Layout.fillWidth: true
        spacing: 10
        Label {
          Layout.fillWidth: true
          horizontalAlignment: Text.AlignHCenter
          text: root.selectedSource ? root.selectedSource.app || root.selectedSource.label : root.tr("他のアプリで音声を再生してください")
          font.pixelSize: root.selectedSource ? 24 : 20
          font.bold: root.selectedSource !== null
        }
        Label {
          Layout.fillWidth: true
          horizontalAlignment: Text.AlignHCenter
          text: root.busy ? (root.state === "connecting" ? root.tr("接続中…") : root.tr("翻訳中  ·  ") + Math.floor(root.seconds/60) + ":" + String(root.seconds%60).padStart(2,"0")) : root.selectedSource ? root.tr("● 再生中") : root.tr("音声を自動で検出します")
          color: root.selectedSource ? root.accent : root.muted
          font.pixelSize: 12
        }
        C.ComboBox {
          id: sourceBox
          visible: root.sourceItems.length > 1
          Layout.fillWidth: true
          implicitHeight: 38
          enabled: !root.busy
          model: root.sourceItems
          textRole: "label"
          onActivated: root.selectedId = root.sourceItems[currentIndex].id
          palette.text: root.fg
          palette.buttonText: root.fg
          palette.button: root.buttonBg
          palette.base: root.buttonBg
          palette.window: root.buttonBg
          palette.highlight: root.hoverBg
        }
      }
      Rectangle {
        visible: root.showSettings && !root.compact
        Layout.fillWidth: true
        implicitHeight: settingsContent.implicitHeight + 24
        color: root.panelBg
        radius: 9
        ColumnLayout {
          id: settingsContent
          anchors.fill: parent; anchors.margins: 12
          spacing: 6
          Label { text: root.tr("翻訳先"); font.bold: true }
          C.ComboBox {
            id: languageBox
            Layout.fillWidth: true
            implicitHeight: 38
            enabled: root.ready && !root.busy && !root.languageSaving && root.languageItems.length > 0
            model: root.languageItems
            textRole: "label"
            onActivated: root.selectLanguage(currentIndex)
            palette.text: root.fg
            palette.buttonText: root.fg
            palette.button: root.buttonBg
            palette.base: root.buttonBg
            palette.window: root.buttonBg
            palette.highlight: root.hoverBg
          }
          Label {
            visible: root.busy || (root.targetPreference === "auto" && root.systemLanguageFallback)
            Layout.fillWidth: true
            text: root.busy ? root.tr("言語の変更は翻訳を停止してから") : root.tr("OSの言語が未対応・未設定のため、英語を使います。")
            color: root.muted; font.pixelSize: 12
          }
          Label { text: root.tr("字幕の表示速度"); font.bold: true }
          C.ComboBox {
            id: modeBox
            Layout.fillWidth: true
            implicitHeight: 38
            model: [root.tr("リアルタイム優先"), root.tr("読みやすさ優先")]
            onModelChanged: Qt.callLater(function() { modeBox.currentIndex = root.displayMode === "realtime" ? 0 : 1 })
            currentIndex: root.displayMode === "realtime" ? 0 : 1
            enabled: root.ready && !root.modeSaving
            onActivated: root.setDisplayMode(currentIndex === 0 ? "realtime" : "readable")
            palette.text: root.fg; palette.buttonText: root.fg
            palette.button: root.buttonBg; palette.base: root.buttonBg; palette.window: root.buttonBg
            palette.highlight: root.hoverBg
          }
          Label {
            Layout.fillWidth: true
            text: root.displayMode === "realtime" ? root.tr("最低0.8秒で最新へ。溜まった字幕は飛ばします。") : root.tr("通常2.2〜6秒。遅れたら短縮し、最低1秒表示します。")
            color: root.muted; font.pixelSize: 12
          }
          Button { text: root.tr("履歴ファイルを開く"); enabled: root.ready; onClicked: root.send({action: "prepare_history"}) }
          Label { text: root.tr("翻訳全文をこのPCに保存します。音声は保存しません。"); Layout.fillWidth: true; color: root.muted; font.pixelSize: 12 }
          Label { text: root.keyReady ? root.tr("OpenAI APIキー · 設定済み") : root.tr("OpenAI APIキーを設定"); font.bold: true }
          RowLayout {
            Layout.fillWidth: true
            C.TextField {
              id: keyInput
              Layout.fillWidth: true
              echoMode: TextInput.Password
              placeholderText: root.tr("sk-… （このPCだけに保存）")
              color: root.fg
              placeholderTextColor: root.muted
              selectByMouse: true
              background: Rectangle { color: root.bg; radius: 5; border.color: root.borderColor }
            }
            Button {
              text: root.tr("保存")
              enabled: root.ready && !root.busy && keyInput.text.length > 0
              onClicked: { root.send({action: "save_key", key: keyInput.text}); keyInput.clear() }
            }
          }
          Label {
            Layout.fillWidth: true
            text: root.tr("開始すると選択した音声をOpenAIに送信します（従量課金）。APIキーはこのPCに保存します。")
            color: root.muted; font.pixelSize: 12
          }
          Button { text: root.tr("表示デモ（日本語）"); enabled: root.ready && !root.busy; onClicked: root.begin(true) }
        }
      }

      Label { visible: !root.compact && (root.errorText.length > 0 || root.sourceError.length > 0); text: root.errorText || root.sourceError; color: "#ffa6a6"; Layout.fillWidth: true; font.pixelSize: 12 }
      RowLayout {
        visible: !root.compact && !root.showSettings
        Layout.alignment: Qt.AlignHCenter
        Button {
          text: root.busy ? root.tr("停止") : root.tr("▶ 翻訳を開始")
          primary: !root.busy
          implicitWidth: 160
          implicitHeight: 46
          enabled: root.busy || root.canStart
          onClicked: root.busy ? root.stopAndReturn() : root.begin(false)
        }
        Button { visible: root.busy; text: root.tr("字幕に戻る"); onClicked: root.compact = true }
      }
      Item { visible: !root.compact; Layout.fillHeight: true }
      Item {
        visible: root.compact
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.minimumHeight: root.compact ? 80 : 110
        Text {
          id: captionText
          anchors.fill: parent
          anchors.margins: root.compact ? 4 : 12
          text: root.displayedCaption || (root.state === "connecting" ? root.tr("接続中…") : "")
          textFormat: Text.PlainText
          color: root.warmText ? "#ffe49b" : "#e6edf3"
          font.pixelSize: root.textSize
          font.weight: root.boldText ? Font.Bold : Font.Medium
          style: root.outlineText ? Text.Outline : Text.Normal
          styleColor: "#111111"
          fontSizeMode: Text.FixedSize
          wrapMode: Text.Wrap
          horizontalAlignment: Text.AlignHCenter
          verticalAlignment: Text.AlignVCenter
          // One immutable cue per update. No editor, cursor, scrolling or fades.
        }
        MouseArea {
          anchors.fill: parent
          enabled: root.compact
          acceptedButtons: Qt.LeftButton | Qt.RightButton
          onDoubleClicked: root.compact = false
          onClicked: function(mouse) { if (mouse.button === Qt.RightButton) root.compact = false }
        }
      }

    }
    // Overlay: its appearance never moves or reflows the subtitle.
    Item {
      anchors.fill: parent
      z: 10
      HoverHandler {
        enabled: root.compact
        onHoveredChanged: {
          if (hovered) root.pointerMoved(point.position.x, point.position.y)
          else root.pointerLeft()
        }
        onPointChanged: if (hovered) root.pointerMoved(point.position.x, point.position.y)
      }
      Rectangle {
        id: toolbar
        objectName: "subtitleToolbar"
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 10
        width: Math.min(parent.width - 20, 520)
        height: toolbarContents.implicitHeight + 16
        radius: 10
        color: Qt.rgba(root.panelBg.r, root.panelBg.g, root.panelBg.b, 0.97)
        border.color: root.borderColor
        opacity: root.compact && root.toolbarShown ? 1 : 0
        visible: opacity > 0
        enabled: root.compact && root.toolbarShown
        Behavior on opacity { NumberAnimation { duration: 160 } }
        Column {
          id: toolbarContents
          anchors { left: parent.left; right: parent.right; top: parent.top; margins: 8 }
          spacing: 8
          Flow {
            id: toolbarButtons
            width: parent.width
            spacing: 6
            Button { text: root.tr("停止"); enabled: root.busy; onClicked: root.stopAndReturn() }
            Button {
              text: [root.tr("文字：小さめ"), root.tr("文字：標準"), root.tr("文字：大きめ")][root.textSizeChoice]
              onClicked: { root.textSizeChoice = (root.textSizeChoice + 1) % 3; root.revealToolbar() }
              C.ToolTip.text: root.tr("ウィンドウに合わせて自動調整")
              C.ToolTip.visible: hovered
            }
            Button { text: root.tr("見た目"); onClicked: { root.appearanceOpen = !root.appearanceOpen; root.moreOpen = false; root.revealToolbar() } }
            Button { text: "⋯"; onClicked: { root.moreOpen = !root.moreOpen; root.appearanceOpen = false; root.revealToolbar() } }
          }
          Flow {
            visible: root.appearanceOpen
            width: parent.width
            spacing: 6
            Button { text: root.boldText ? root.tr("太字 ✓") : root.tr("太字"); onClicked: root.boldText = !root.boldText }
            Button { text: root.outlineText ? root.tr("縁取り ✓") : root.tr("縁取り"); onClicked: root.outlineText = !root.outlineText }
            Button { text: root.warmText ? root.tr("文字：黄") : root.tr("文字：白"); onClicked: root.warmText = !root.warmText }
            Button { text: [root.tr("背景：黒"), root.tr("背景：半透明"), root.tr("背景：透明")][root.backgroundChoice]; onClicked: root.backgroundChoice = (root.backgroundChoice+1)%3 }
          }
          Flow {
            visible: root.moreOpen
            width: parent.width
            spacing: 6
            Button { text: root.displayMode === "realtime" ? root.tr("速度：リアルタイム") : root.tr("速度：読みやすさ"); enabled: root.ready && !root.modeSaving; onClicked: root.setDisplayMode(root.displayMode === "realtime" ? "readable" : "realtime") }
            Button { text: root.tr("音声を変更"); onClicked: root.stopAndReturn() }
            Button { text: root.tr("設定"); onClicked: { root.compact = false; root.showSettings = true } }
            Button { text: root.tr("操作に戻る"); onClicked: root.compact = false }
            Button { text: root.tr("閉じる"); onClicked: root.close() }
          }
        }
      }
    }
    }
  }
}
