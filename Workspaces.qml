import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Clients.js" as Clients
import "Layout.js" as Layout

BarWidget {
  id: root
  moduleName: "hamza.berth"

  // Quickshell writes a workspace change onto the monitor that was focused
  // before the change. A cross-screen switch therefore leaves the old screen
  // showing the new name. The focused label comes from Hyprland's own events
  // instead of that property.
  //
  // Lock can drop a display. Hyprland parks its workspaces on a remaining
  // screen until the output returns. The last IPC snapshot keeps that
  // temporary monitor, so the remaining bar would draw the parked name
  // after unlock. A pinned name is drawn only on its configured screen.
  property var labels: ({})
  property string pendingName: ""
  property bool live: false
  property int generation: 0
  property int seedPasses: 0
  // address -> workspace name. See Clients.js.
  property var clients: ({})
  property var droppedDuringSeed: ({})
  property bool seeding: true
  property int seedAttempts: 0
  property var layoutScreens: []
  property int layoutGeneration: 0

  readonly property string layoutPath: Quickshell.env("HOME") + "/.config/omarchy/plugins/hamza.berth/layout.json"
  readonly property var assignment: {
    var bump = generation + layoutGeneration
    var live = []
    var monitors = Hyprland.monitors.values
    for (var i = 0; i < monitors.length; i++) {
      var monitor = monitors[i]
      if (!monitor) continue
      var ipc = monitor.lastIpcObject || {}
      var description = String(ipc.description || "")
      if (!description) description = [ipc.make, ipc.model, ipc.serial].join(" ")
      live.push({
        name: String(monitor.name || ipc.name || ""),
        description: description,
        serial: String(ipc.serial || "")
      })
    }
    return Layout.assign({ screens: layoutScreens }, live)
  }

  readonly property var barWindow: QsWindow.window
  readonly property var screen: barWindow ? barWindow.screen : null
  readonly property string screenName: screen ? String(screen.name || "") : ""
  readonly property string workspaceName: {
    var table = labels
    return screenName && table[screenName] ? String(table[screenName]) : ""
  }

  // Every workspace assigned to this screen, plus any other occupied workspace
  // that landed here (such as a numbered one). Buttons hide themselves when
  // the workspace has no window and is not the one you are on.
  readonly property var screenNames: {
    var bump = generation + layoutGeneration
    var screen = screenName
    var pinned = (assignment.byConnector && assignment.byConnector[screen]) || []
    var names = []
    for (var i = 0; i < pinned.length; i++) names.push(pinned[i])
    var values = Hyprland.workspaces.values
    for (var n = 0; n < values.length; n++) {
      var workspace = values[n]
      if (!workspace || !workspace.name) continue
      var name = String(workspace.name)
      if (name.indexOf("special:") === 0) continue
      // Pinned names stay on their configured screen, even while Hyprland
      // has parked them elsewhere during a display power cycle.
      if (assignment.reserved && assignment.reserved[name]) continue
      if (workspaceMonitor(workspace) !== screen) continue
      if (names.indexOf(name) !== -1) continue
      if (workspaceWindows(workspace) > 0) names.push(name)
    }
    return names
  }

  readonly property real trailingGap: vertical ? 0 : Style.spaceReal(1.5)

  function pinnedScreen(name) {
    var owner = assignment.owner || {}
    return owner[name] ? String(owner[name]) : ""
  }

  function reservedName(name) {
    var reserved = assignment.reserved || {}
    return !!reserved[name]
  }

  function workspaceMonitor(workspace) {
    var ipc = workspace.lastIpcObject
    if (ipc && ipc.monitor) return String(ipc.monitor)
    var monitor = workspace.monitor
    if (!monitor) return ""
    if (typeof monitor === "string") return monitor
    return String(monitor.name || "")
  }

  function commitClients(next) {
    if (next === clients) return
    clients = next
    generation += 1
  }

  function rememberDrop(address) {
    var id = Clients.normalizeAddress(address)
    if (!id) return
    var dropped = {}
    var current = droppedDuringSeed
    for (var key in current) dropped[key] = current[key]
    dropped[id] = true
    droppedDuringSeed = dropped
  }

  function handleWindowEvent(name, parts) {
    if (seeding && name === "closewindow") rememberDrop(parts.length ? parts[0] : "")
    commitClients(Clients.applyEvent(clients, name, parts))
  }

  function takeSeed(text) {
    var listed
    try {
      listed = JSON.parse(text || "")
    } catch (e) {
      return false
    }
    if (!Array.isArray(listed)) return false
    commitClients(Clients.mergeSeed(clients, Clients.fromHyprctl(listed), droppedDuringSeed))
    droppedDuringSeed = ({})
    seeding = false
    return true
  }

  function requestSeed() {
    if (seedProc.running) return
    if (seedAttempts >= 5) {
      seeding = false
      return
    }
    seeding = true
    seedAttempts += 1
    seedProc.running = true
  }

  function windowsFor(name) {
    var bump = generation
    return Clients.count(clients, name)
  }

  function workspaceWindows(workspace) {
    if (!workspace || !workspace.name) return 0
    return windowsFor(String(workspace.name))
  }

  function applyLayout(content) {
    var parsed
    try {
      parsed = JSON.parse(String(content || ""))
    } catch (e) {
      parsed = null
    }
    layoutScreens = parsed && parsed.screens ? parsed.screens : []
    layoutGeneration += 1
  }

  function setLabel(monitorName, workspaceName) {
    if (!monitorName || !workspaceName) return
    if (reservedName(workspaceName)) {
      var owner = pinnedScreen(workspaceName)
      if (!owner) return
      monitorName = owner
    }
    var next = {}
    var current = labels
    for (var key in current) next[key] = current[key]
    if (next[monitorName] === workspaceName) return
    next[monitorName] = workspaceName
    labels = next
  }

  function seed() {
    if (live) return
    var values = Hyprland.monitors.values
    var next = {}
    var current = labels
    for (var key in current) next[key] = current[key]
    var found = 0
    for (var i = 0; i < values.length; i++) {
      var monitor = values[i]
      var workspace = monitor ? monitor.activeWorkspace : null
      if (!monitor || !monitor.name || !workspace || !workspace.name) continue
      var monName = String(monitor.name)
      var wsName = String(workspace.name)
      if (reservedName(wsName) && pinnedScreen(wsName) !== monName) continue
      next[monName] = wsName
      found += 1
    }
    if (found > 0) labels = next
  }

  function focusWorkspace(name) {
    var values = Hyprland.workspaces.values
    for (var i = 0; i < values.length; i++) {
      var workspace = values[i]
      if (!workspace || String(workspace.name) !== name) continue
      workspace.activate()
      return
    }
  }

  // Re-read each monitor's active workspace, and refuse a snapshot that
  // places a pinned workspace on a screen it is not configured for.
  function refreshLabels() {
    var values = Hyprland.monitors.values
    var next = {}
    var current = labels
    for (var key in current) next[key] = current[key]
    var found = 0
    for (var i = 0; i < values.length; i++) {
      var monitor = values[i]
      var workspace = monitor ? monitor.activeWorkspace : null
      if (!monitor || !monitor.name || !workspace || !workspace.name) continue
      var monName = String(monitor.name)
      var wsName = String(workspace.name)
      var owner = pinnedScreen(wsName)
      if (reservedName(wsName) && owner !== monName) continue
      next[monName] = wsName
      found += 1
    }
    if (found > 0) labels = next
  }

  Timer {
    id: settle
    interval: 50
    repeat: false
    onTriggered: {
      if (root.pendingName === "") return
      var owner = root.pinnedScreen(root.pendingName)
      if (owner) {
        root.setLabel(owner, root.pendingName)
      } else {
        var monitor = Hyprland.focusedMonitor
        if (monitor && monitor.name) root.setLabel(String(monitor.name), root.pendingName)
      }
      root.pendingName = ""
    }
  }

  Timer {
    id: resync
    interval: 50
    repeat: false
    onTriggered: root.refreshLabels()
  }

  Timer {
    id: seedRetryTimer
    interval: 400
    repeat: false
    onTriggered: root.requestSeed()
  }

  FileView {
    path: root.layoutPath
    watchChanges: true
    onFileChanged: reload()
    onLoaded: root.applyLayout(text())
    onLoadFailed: root.applyLayout("")
  }

  Process {
    id: seedProc
    command: ["hyprctl", "clients", "-j"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        if (root.takeSeed(text)) return
        seedRetryTimer.restart()
      }
    }
  }

  Component.onCompleted: root.requestSeed()

  Timer {
    id: seedRetry
    interval: 200
    repeat: true
    running: true
    triggeredOnStart: true
    onTriggered: {
      root.seed()
      root.generation += 1
      root.seedPasses += 1
      var placed = root.assignment.byConnector || {}
      var count = 0
      for (var name in placed) count += 1
      var ready = root.layoutScreens.length > 0 && count >= root.layoutScreens.length && root.workspaceName.length > 0
      if (ready || root.seedPasses > 20) running = false
    }
  }

  Connections {
    target: Hyprland

    function onRawEvent(event) {
      if (!event) return
      var name = String(event.name || "")

      if (name === "openwindow" || name === "movewindow") {
        root.handleWindowEvent(name, event.parse(3))
        return
      }
      if (name === "movewindowv2") {
        root.handleWindowEvent(name, event.parse(3))
        return
      }
      if (name === "closewindow") {
        root.handleWindowEvent(name, event.parse(1))
        return
      }
      if (name === "moveworkspace" || name === "moveworkspacev2") {
        root.generation += 1
        return
      }

      if (name === "monitoradded" || name === "monitorremoved") {
        root.generation += 1
        resync.restart()
        return
      }

      if (name === "workspacev2") {
        root.live = true
        root.generation += 1
        var changed = event.parse(2)
        var workspace = changed.length > 1 ? String(changed[1]) : ""
        var owner = root.pinnedScreen(workspace)
        if (owner) {
          settle.stop()
          root.pendingName = ""
          root.setLabel(owner, workspace)
        } else {
          root.pendingName = workspace
          settle.restart()
        }
        return
      }

      if (name === "focusedmon") {
        root.live = true
        var moved = event.parse(2)
        if (moved.length >= 2) {
          settle.stop()
          root.pendingName = ""
          root.setLabel(String(moved[0]), String(moved[1]))
        }
      }
    }
  }

  implicitWidth: row.implicitWidth + trailingGap
  implicitHeight: row.implicitHeight

  Row {
    id: row
    spacing: Style.space(1)

    Repeater {
      model: root.screenNames

      WidgetButton {
        required property string modelData

        readonly property int windows: root.windowsFor(modelData)
        readonly property bool here: modelData === root.workspaceName
        readonly property bool present: windows > 0 || here

        bar: root.bar
        text: modelData
        tooltipText: modelData
        active: here
        // Occupied workspaces stay listed after you leave them.
        opacity: present ? 1 : 0
        visible: present
        keepSpace: false
        horizontalMargin: 8
        verticalPadding: 6
        fixedHeight: root.barSize
        onPressed: function() { root.focusWorkspace(modelData) }
      }
    }
  }
}
