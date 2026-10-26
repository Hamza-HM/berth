import QtQuick
import Quickshell
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "hamza.berth.setup"

  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false

  function open() {
    if (panelLoader.item && panelLoader.item.open) panelLoader.item.open()
  }

  function close() {
    if (panelLoader.item && panelLoader.item.close) panelLoader.item.close()
  }

  function togglePanel() {
    if (panelLoader.item && panelLoader.item.toggle) panelLoader.item.toggle()
  }

  function injectPanel() {
    var target = panelLoader.item
    if (!target) return
    if ("bar" in target) target.bar = root.bar
    if ("anchorItem" in target) target.anchorItem = editButton
    if ("hostWidget" in target) target.hostWidget = root
  }

  onBarChanged: injectPanel()

  implicitWidth: editButton.implicitWidth
  implicitHeight: editButton.implicitHeight

  Loader {
    id: panelLoader
    active: true
    source: Quickshell.env("HOME") + "/.config/omarchy/plugins/hamza.berth/SetupPanel.qml"
    visible: false
    onLoaded: {
      root.injectPanel()
      Qt.callLater(root.injectPanel)
    }
  }

  BarIconButton {
    id: editButton
    bar: root.bar
    text: "\uf304"
    tooltipText: "Edit workspaces"
    slotSize: root.barSize
    onPressed: function() { root.togglePanel() }
  }
}
