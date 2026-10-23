import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "Layout.js" as Layout
import "Setup.js" as Setup

Panel {
  id: root
  moduleName: "hamza.berth"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  property var sections: []
  property var layoutScreens: []
  property string bindingsText: ""
  property string notice: ""
  property bool noticeIsError: false
  property bool confirming: false
  property bool saving: false
  property bool savedFlash: false
  property var flashScreen: null
  property int editRevision: 0

  // Hyprland drops the mouse release when a click also focuses the window
  // under this panel. Buttons that wait for the release ignore that click.
  component ActOnPress: MouseArea {
    anchors.fill: parent
    z: 1
    preventStealing: true
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    signal act()
    onContainsMouseChanged: parent.hasCursor = containsMouse
    onPressed: act()
  }

  readonly property string layoutPath: Quickshell.env("HOME") + "/.config/omarchy/plugins/hamza.berth/layout.json"
  readonly property string fileWrite: "dir=${1%/*}; mkdir -p -- \"$dir\"; tmp=$1.tmp; printf '%s' \"$2\" > \"$tmp\" && mv -- \"$tmp\" \"$1\""
  readonly property string bindingsPath: Quickshell.env("HOME") + "/.config/hypr/bindings.lua"
  readonly property bool bindingsReady: Setup.bindingsInstalled(bindingsText)
  readonly property color ink: bar ? bar.foreground : Commons.Color.foreground
  readonly property color quiet: Qt.darker(ink, 1.45)

  function open() {
    reloadDraft()
    notice = ""
    savedFlash = false
    confirming = false
    controller.show()
  }

  function liveMonitors() {
    var list = []
    var values = Hyprland.monitors.values
    for (var i = 0; i < values.length; i++) {
      var monitor = values[i]
      if (!monitor) continue
      var ipc = monitor.lastIpcObject || {}
      list.push({
        name: String(monitor.name || ipc.name || ""),
        description: String(ipc.description || ""),
        make: String(ipc.make || ""),
        model: String(ipc.model || ""),
        serial: String(ipc.serial || ""),
        x: Number(ipc.x || 0),
        y: Number(ipc.y || 0)
      })
    }
    return list
  }

  function reloadDraft() {
    sections = Setup.draft(Layout.normalize({ screens: layoutScreens }), liveMonitors(), Layout.matches)
  }

  function flash(connector) {
    var screens = Quickshell.screens || []
    flashScreen = null
    for (var i = 0; i < screens.length; i++) {
      if (String(screens[i].name || "") === String(connector || "")) {
        flashScreen = screens[i]
        break
      }
    }
    if (flashScreen) flashTimer.restart()
  }

  function commit() {
    if (saving || layoutWrite.running) return
    var result = Setup.save(sections, Layout.normalize({ screens: layoutScreens }), liveMonitors(), Layout.matches)
    if (!result.ok) {
      notice = result.message
      noticeIsError = true
      return
    }
    saving = true
    savedFlash = false
    notice = ""
    noticeIsError = false
    layoutWrite.payload = JSON.stringify(result.layout, null, 2) + "\n"
    layoutWrite.running = true
  }

  function finishSave(code) {
    if (code !== 0) {
      saving = false
      notice = "Could not save."
      noticeIsError = true
      return
    }
    try {
      layoutScreens = JSON.parse(layoutWrite.payload).screens || []
    } catch (e) {
      layoutScreens = []
    }
    reloadDraft()
    if (bindingsReady) {
      reloadHypr.running = true
      return
    }
    markSaved()
  }

  function markSaved() {
    saving = false
    notice = ""
    noticeIsError = false
    savedFlash = true
    savedTimer.restart()
  }

  function installBindings() {
    if (bindingsWrite.running) return
    bindingsWrite.payload = Setup.withBindings(bindingsText)
    bindingsWrite.running = true
  }

  FileView {
    id: layoutFile
    path: root.layoutPath
    watchChanges: true
    onFileChanged: reload()
    onLoaded: {
      root.applyLayout(text())
      if (root.opened) root.reloadDraft()
    }
    onLoadFailed: root.applyLayout("")
  }

  function applyLayout(content) {
    var parsed
    try {
      parsed = JSON.parse(String(content || ""))
    } catch (e) {
      parsed = null
    }
    layoutScreens = parsed && parsed.screens ? parsed.screens : []
  }

  FileView {
    id: bindingsFile
    path: root.bindingsPath
    watchChanges: true
    onFileChanged: reload()
    onLoaded: root.bindingsText = String(text() || "")
    onLoadFailed: root.bindingsText = ""
  }

  Process {
    id: layoutWrite
    property string payload: ""
    command: ["bash", "-c", root.fileWrite, "berth-write", root.layoutPath, payload]
    onExited: function(code) { root.finishSave(code) }
  }

  Process {
    id: bindingsWrite
    property string payload: ""
    command: ["bash", "-c", root.fileWrite, "berth-write", root.bindingsPath, payload]
    onExited: function(code) {
      root.confirming = false
      if (code !== 0) {
        root.notice = "Could not update the keybindings."
        root.noticeIsError = true
        return
      }
      root.notice = "Keybindings added."
      root.noticeIsError = false
      reloadHypr.running = true
    }
  }

  Process {
    id: reloadHypr
    command: ["hyprctl", "reload"]
    onExited: function(code) {
      if (!root.saving) return
      if (code !== 0) {
        root.saving = false
        root.notice = "Saved, but the keybindings did not reload."
        root.noticeIsError = true
        return
      }
      root.markSaved()
    }
  }

  Timer {
    id: savedTimer
    interval: 1200
    repeat: false
    onTriggered: root.savedFlash = false
  }

  Timer {
    id: flashTimer
    interval: 700
    repeat: false
    onTriggered: root.flashScreen = null
  }

  PanelWindow {
    visible: root.flashScreen !== null
    screen: root.flashScreen
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    color: "transparent"
    // Empty input region, so the outline does not take clicks.
    mask: Region {}
    anchors.top: true
    anchors.left: true
    anchors.right: true
    anchors.bottom: true

    Rectangle {
      anchors.fill: parent
      anchors.margins: Style.space(10)
      color: "transparent"
      radius: Style.space(12)
      border.width: Math.max(2, Style.space(3))
      border.color: Commons.Color.accent
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.hostWidget || root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(420))
    contentHeight: panel.fittedContentHeight(editor.implicitHeight, Style.space(560))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      blocked: true
      onCloseRequested: root.close()

      Flickable {
        id: scroll
        anchors.fill: parent
        contentWidth: width
        contentHeight: editor.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height

        Column {
          id: editor
          width: scroll.width
          spacing: Style.space(14)

          Column {
            width: parent.width
            spacing: Style.space(4)

            Text {
              text: "Workspaces"
              color: root.ink
              font.family: Style.font.family
              font.pixelSize: Style.font.title
            }
            Text {
              width: parent.width
              wrapMode: Text.WordWrap
              text: "Name the workspaces on each screen. Click a key, then press the new one."
              color: root.quiet
              font.family: Style.font.family
              font.pixelSize: Style.font.bodySmall
            }
          }

          Text {
            visible: root.sections.length === 0
            width: parent.width
            wrapMode: Text.WordWrap
            text: "No screen is connected."
            color: root.ink
            font.family: Style.font.family
            font.pixelSize: Style.font.body
          }

          Repeater {
            model: root.sections

            Column {
              id: sectionBox
              required property var modelData
              required property int index
              width: editor.width
              spacing: Style.space(6)

              PanelSeparator {
                visible: sectionBox.index > 0
                foreground: root.ink
              }

              Item {
                width: parent.width
                height: Math.max(screenTitle.implicitHeight, showButton.implicitHeight)

                PanelSectionHeader {
                  id: screenTitle
                  text: sectionBox.modelData.model || "Screen"
                  foreground: root.ink
                  anchors.left: parent.left
                  anchors.verticalCenter: parent.verticalCenter
                }

                Button {
                  id: showButton
                  anchors.right: parent.right
                  anchors.verticalCenter: parent.verticalCenter
                  text: "Show"
                  fontSize: Style.font.bodySmall
                  foreground: root.quiet
                  verticalPadding: 0
                  horizontalPadding: Style.space(4)
                  ActOnPress { onAct: root.flash(sectionBox.modelData.connector) }
                }
              }

              Text {
                visible: sectionBox.modelData.twin
                text: "Same model as another screen"
                color: root.quiet
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
              }

              Repeater {
                model: sectionBox.modelData.workspaces

                Row {
                  id: nameRow
                  required property var modelData
                  required property int index
                  width: sectionBox.width
                  spacing: Style.space(6)

                  TextField {
                    id: nameField
                    width: nameRow.width - keyText.width - homeButton.width - removeButton.width - nameRow.spacing * 3
                    text: nameRow.modelData.name
                    placeholderText: "Name"
                    foreground: root.ink
                    verticalPadding: Style.space(4)
                    Keys.onEscapePressed: root.close()
                    onTextEdited: nameField.keepName()
                    onEditingFinished: nameField.keepName()
                    function keepName() {
                      var rows = root.sections[sectionBox.index].workspaces
                      if (rows && rows[nameRow.index]) rows[nameRow.index].name = text
                      root.editRevision += 1
                    }
                  }

                  Item {
                    id: keyText
                    readonly property string label: {
                      var bump = root.editRevision
                      return Setup.keyLabel(Setup.rowKey(root.sections, sectionBox.index, nameRow.index))
                    }
                    width: Style.space(88)
                    height: nameField.implicitHeight
                    anchors.verticalCenter: parent.verticalCenter
                    activeFocusOnTab: true

                    Text {
                      anchors.fill: parent
                      horizontalAlignment: Text.AlignRight
                      verticalAlignment: Text.AlignVCenter
                      text: keyText.activeFocus ? "Press a key" : (keyText.label !== "Click only" ? keyText.label : "Set")
                      color: keyText.activeFocus ? root.ink : root.quiet
                      font.family: Style.font.family
                      font.pixelSize: Style.font.caption
                      elide: Text.ElideRight
                    }

                    MouseArea {
                      anchors.fill: parent
                      z: 1
                      preventStealing: true
                      cursorShape: Qt.PointingHandCursor
                      onPressed: keyText.forceActiveFocus()
                    }

                    Keys.onPressed: function(event) {
                      if (event.key === Qt.Key_Escape) {
                        keyText.focus = false
                        event.accepted = true
                        return
                      }
                      var key = Setup.keyFromScan(event.nativeScanCode, event.key)
                      if (!key) {
                        event.accepted = true
                        return
                      }
                      nameField.keepName()
                      var result = Setup.setRowKey(root.sections, sectionBox.index, nameRow.index, key)
                      if (!result.ok) {
                        root.notice = result.message
                        root.noticeIsError = true
                      } else {
                        var rows = root.sections[sectionBox.index].workspaces
                        if (rows && rows[nameRow.index]) rows[nameRow.index].key = key
                        root.editRevision += 1
                        root.notice = "Save to use Super + " + Setup.keyLabel(key) + "."
                        root.noticeIsError = false
                      }
                      keyText.focus = false
                      event.accepted = true
                    }
                  }

                  PanelActionButton {
                    id: homeButton
                    readonly property bool marked: {
                      var bump = root.editRevision
                      return sectionBox.modelData.homeIndex === nameRow.index
                    }
                    anchors.verticalCenter: parent.verticalCenter
                    iconText: marked ? "●" : "○"
                    tooltipText: "Home"
                    foreground: marked ? root.ink : root.quiet
                    hoverColor: root.ink
                    ActOnPress { onAct: root.sections = Setup.setHome(root.sections, sectionBox.index, nameRow.index) }
                  }

                  PanelActionButton {
                    id: removeButton
                    anchors.verticalCenter: parent.verticalCenter
                    iconText: "–"
                    tooltipText: "Remove"
                    foreground: root.ink
                    ActOnPress { onAct: root.sections = Setup.removeWorkspace(root.sections, sectionBox.index, nameRow.index) }
                  }
                }
              }

              Button {
                text: "Add workspace"
                fontSize: Style.font.bodySmall
                foreground: root.quiet
                verticalPadding: Style.space(2)
                ActOnPress { onAct: root.sections = Setup.addWorkspace(root.sections, sectionBox.index) }
              }
            }
          }

          Button {
            readonly property string label: root.saving ? "Saving" : (root.savedFlash ? "Saved" : "Save")
            width: Style.space(112)
            text: label
            iconText: root.saving ? "\uf110" : ""
            iconSize: fontSize
            iconSpinning: root.saving
            bordered: true
            ActOnPress { onAct: root.commit() }
          }

          Text {
            width: parent.width
            wrapMode: Text.WordWrap
            text: root.notice !== "" ? root.notice : (root.bindingsReady ? "Keybindings are in place." : "")
            visible: text !== ""
            color: root.noticeIsError ? Commons.Color.urgent : root.quiet
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
          }

          Button {
            visible: !root.bindingsReady && !root.confirming
            text: "Add keybindings"
            fontSize: Style.font.bodySmall
            foreground: root.quiet
            verticalPadding: Style.space(2)
            ActOnPress { onAct: root.confirming = true }
          }

          Column {
            visible: root.confirming
            width: parent.width
            spacing: Style.space(8)

            Text {
              width: parent.width
              wrapMode: Text.WordWrap
              text: "This adds one line to bindings.lua. Your other keys stay as they are."
              color: root.ink
              font.family: Style.font.family
              font.pixelSize: Style.font.bodySmall
            }

            Row {
              spacing: Style.space(8)

              Button {
                text: "Add"
                fontSize: Style.font.bodySmall
                foreground: root.ink
                verticalPadding: Style.space(2)
                ActOnPress { onAct: root.installBindings() }
              }
              Button {
                text: "Cancel"
                fontSize: Style.font.bodySmall
                foreground: root.quiet
                verticalPadding: Style.space(2)
                ActOnPress { onAct: root.confirming = false }
              }
            }
          }
        }
      }
    }
  }
}
